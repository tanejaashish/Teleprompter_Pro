import { PrismaClient } from "@prisma/client";
import AWS from "aws-sdk";
import { Readable } from "stream";

const prisma = new PrismaClient();

export class EnterpriseCloudStorageService {
  private s3: AWS.S3;
  private cloudfront: AWS.CloudFront;
  private buckets: {
    hot: string; // Frequently accessed
    warm: string; // Occasional access
    cold: string; // Archive
  };

  constructor() {
    this.s3 = new AWS.S3({
      region: process.env.AWS_REGION,
      signatureVersion: "v4",
    });

    this.cloudfront = new AWS.CloudFront();

    this.buckets = {
      hot: process.env.S3_BUCKET_HOT!,
      warm: process.env.S3_BUCKET_WARM!,
      cold: process.env.S3_BUCKET_COLD!,
    };
  }

  async uploadWithIntelligentTiering(
    file: Buffer | Readable,
    key: string,
    userId: string,
    metadata: Record<string, any> = {},
  ): Promise<UploadResult> {
    // Determine storage class based on user's subscription
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: { subscription: true },
    });

    const storageClass = this.determineStorageClass(user?.subscription);
    const bucket = this.selectBucket(storageClass);

    // Calculate file hash for deduplication
    const fileHash = await this.calculateHash(file);

    // Check if file already exists
    const existingFile = await this.checkDuplication(fileHash);
    if (existingFile) {
      // Link to existing file instead of uploading
      return this.linkToExisting(existingFile, userId, metadata);
    }

    // Prepare upload
    const uploadParams: AWS.S3.PutObjectRequest = {
      Bucket: bucket,
      Key: key,
      Body: file,
      StorageClass: storageClass,
      ServerSideEncryption: "AES256",
      Metadata: {
        ...metadata,
        userId,
        uploadDate: new Date().toISOString(),
        fileHash,
      },
      ContentType: this.detectContentType(key),
    };

    // Use multipart upload for large files
    if (file instanceof Buffer && file.length > 100 * 1024 * 1024) {
      return await this.multipartUpload(uploadParams);
    }

    // Standard upload
    const result = await this.s3.upload(uploadParams).promise();

    // Create CloudFront distribution for Pro users
    let cdnUrl = result.Location;
    if (user?.subscription?.tier === "pro") {
      cdnUrl = await this.setupCDN(bucket, key);
    }

    // Save to database
    const upload = await prisma.upload.create({
      data: {
        userId,
        key,
        bucket,
        size: file instanceof Buffer ? file.length : 0,
        url: result.Location,
        cdnUrl,
        storageClass,
        fileHash,
        metadata: metadata as any,
        status: "completed",
      },
    });

    // Set up lifecycle policies
    await this.configureLifecycle(bucket, key, storageClass);

    return {
      uploadId: upload.id,
      url: cdnUrl || result.Location,
      key,
      bucket,
      size: upload.size,
    };
  }

  private async multipartUpload(
    params: AWS.S3.PutObjectRequest,
  ): Promise<AWS.S3.ManagedUpload.SendData> {
    const multipartParams = {
      ...params,
      partSize: 10 * 1024 * 1024, // 10MB parts
      queueSize: 4, // Parallel uploads
    };

    return new Promise((resolve, reject) => {
      const upload = this.s3.upload(multipartParams);

      // Track progress
      upload.on("httpUploadProgress", (progress) => {
        const percent = Math.round((progress.loaded / progress.total) * 100);
        this.emitProgress(params.Key!, percent);
      });

      upload.send((err, data) => {
        if (err) reject(err);
        else resolve(data);
      });
    });
  }

  async generatePresignedUrl(
    key: string,
    operation: "getObject" | "putObject",
    expiresIn: number = 3600,
    conditions?: any,
  ): Promise<string> {
    const params: any = {
      Bucket: this.buckets.hot,
      Key: key,
      Expires: expiresIn,
    };

    if (operation === "putObject" && conditions) {
      // Add upload conditions
      params.ContentType = conditions.contentType;
      params.ContentLength = conditions.contentLength;
      params.Metadata = conditions.metadata;
    }

    return await this.s3.getSignedUrlPromise(operation, params);
  }

  async setupCDN(bucket: string, key: string): Promise<string> {
    const distributionConfig = {
      CallerReference: `${bucket}-${key}-${Date.now()}`,
      Comment: "TelePrompt Pro CDN Distribution",
      DefaultCacheBehavior: {
        TargetOriginId: bucket,
        ViewerProtocolPolicy: "redirect-to-https",
        TrustedSigners: {
          Enabled: false,
          Quantity: 0,
        },
        ForwardedValues: {
          QueryString: false,
          Cookies: { Forward: "none" },
        },
        MinTTL: 0,
        DefaultTTL: 86400,
        MaxTTL: 31536000,
      },
      Origins: {
        Quantity: 1,
        Items: [
          {
            Id: bucket,
            DomainName: `${bucket}.s3.amazonaws.com`,
            S3OriginConfig: {
              OriginAccessIdentity: "",
            },
          },
        ],
      },
      Enabled: true,
    };

    const distribution = await this.cloudfront
      .createDistribution({
        DistributionConfig: distributionConfig as any,
      })
      .promise();

    return `https://${distribution.Distribution?.DomainName}/${key}`;
  }

  private determineStorageClass(subscription: any): string {
    if (!subscription) return "STANDARD_IA";

    switch (subscription.tier) {
      case "pro":
        return "STANDARD";
      case "advanced":
        return "INTELLIGENT_TIERING";
      default:
        return "STANDARD_IA";
    }
  }

  private async configureLifecycle(
    bucket: string,
    key: string,
    storageClass: string,
  ): Promise<void> {
    const rules = [
      {
        Id: `lifecycle-${key}`,
        Status: "Enabled",
        Prefix: key,
        Transitions: [
          {
            Days: 30,
            StorageClass: "STANDARD_IA",
          },
          {
            Days: 90,
            StorageClass: "GLACIER",
          },
        ],
        Expiration: {
          Days: 365,
        },
      },
    ];

    if (storageClass === "STANDARD") {
      // Pro users get longer retention
      rules[0].Expiration.Days = 730;
    }

    await this.s3
      .putBucketLifecycleConfiguration({
        Bucket: bucket,
        LifecycleConfiguration: {
          Rules: rules as any,
        },
      })
      .promise();
  }

  // Bandwidth optimization
  async optimizedDownload(
    key: string,
    userId: string,
    options: DownloadOptions = {},
  ): Promise<Readable> {
    // Check user's bandwidth limit
    const bandwidth = await this.getUserBandwidth(userId);

    const params: AWS.S3.GetObjectRequest = {
      Bucket: this.buckets.hot,
      Key: key,
    };

    // Range request for partial downloads
    if (options.range) {
      params.Range = `bytes=${options.range.start}-${options.range.end}`;
    }

    const stream = this.s3.getObject(params).createReadStream();

    // Apply bandwidth throttling
    if (bandwidth.limit && !bandwidth.unlimited) {
      return this.throttleStream(stream, bandwidth.limit);
    }

    return stream;
  }

  private throttleStream(stream: Readable, bytesPerSecond: number): Readable {
    const throttle = new Transform({
      transform(chunk, encoding, callback) {
        const delay = (chunk.length / bytesPerSecond) * 1000;
        setTimeout(() => callback(null, chunk), delay);
      },
    });

    return stream.pipe(throttle);
  }
}
