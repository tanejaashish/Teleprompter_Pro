// Complete Video Processing Pipeline
// Advanced video processing with FFmpeg, ML enhancement, and cloud upload

import { PrismaClient } from "@prisma/client";
import ffmpeg from "fluent-ffmpeg";
import path from "path";
import fs from "fs";
import { EventEmitter } from "events";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

const prisma = new PrismaClient();

export interface VideoProcessingJob {
  id: string;
  userId: string;
  recordingId: string;
  inputPath: string;
  status: "pending" | "processing" | "completed" | "failed";
  progress: number;
  stages: ProcessingStage[];
  error?: string;
}

export interface ProcessingStage {
  name: string;
  status: "pending" | "processing" | "completed" | "failed";
  progress: number;
  startTime?: Date;
  endTime?: Date;
}

export interface VideoProcessingOptions {
  quality: "720p" | "1080p" | "4K";
  format: "mp4" | "mov" | "webm";
  bitrate?: number;
  fps?: number;
  codec?: string;
  applyWatermark?: boolean;
  watermarkPath?: string;
  generateThumbnail?: boolean;
  extractAudio?: boolean;
  normalizeAudio?: boolean;
  stabilization?: boolean;
  colorCorrection?: boolean;
}

export class VideoProcessingService extends EventEmitter {
  private s3Client: S3Client;
  private activeJobs: Map<string, VideoProcessingJob> = new Map();

  constructor() {
    super();
    this.s3Client = new S3Client({
      region: process.env.AWS_REGION || "us-east-1",
      credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
      },
    });
  }

  // Main processing pipeline
  async processVideo(
    userId: string,
    recordingId: string,
    inputPath: string,
    options: VideoProcessingOptions,
  ): Promise<string> {
    const jobId = `job_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    const job: VideoProcessingJob = {
      id: jobId,
      userId,
      recordingId,
      inputPath,
      status: "pending",
      progress: 0,
      stages: [
        { name: "validation", status: "pending", progress: 0 },
        { name: "transcoding", status: "pending", progress: 0 },
        { name: "thumbnail", status: "pending", progress: 0 },
        { name: "audio_processing", status: "pending", progress: 0 },
        { name: "upload", status: "pending", progress: 0 },
      ],
    };

    this.activeJobs.set(jobId, job);
    this.emit("job_created", job);

    try {
      job.status = "processing";
      this.emit("job_started", job);

      // Stage 1: Validate input
      await this.validateVideo(job, inputPath);

      // Stage 2: Transcode video
      const transcodedPath = await this.transcodeVideo(job, inputPath, options);

      // Stage 3: Generate thumbnail
      let thumbnailPath: string | undefined;
      if (options.generateThumbnail !== false) {
        thumbnailPath = await this.generateThumbnail(job, transcodedPath);
      }

      // Stage 4: Process audio
      if (options.normalizeAudio || options.extractAudio) {
        await this.processAudio(job, transcodedPath, options);
      }

      // Stage 5: Upload to cloud
      const cloudUrl = await this.uploadToCloud(
        job,
        transcodedPath,
        thumbnailPath,
      );

      // Update database
      await this.updateRecordingInDatabase(
        recordingId,
        cloudUrl,
        thumbnailPath,
        transcodedPath,
      );

      // Cleanup local files
      await this.cleanup(inputPath, transcodedPath);

      job.status = "completed";
      job.progress = 100;
      this.emit("job_completed", job);
      this.activeJobs.delete(jobId);

      return cloudUrl;
    } catch (error: any) {
      job.status = "failed";
      job.error = error.message;
      this.emit("job_failed", { job, error });
      this.activeJobs.delete(jobId);
      throw error;
    }
  }

  // Stage 1: Validate video
  private async validateVideo(
    job: VideoProcessingJob,
    inputPath: string,
  ): Promise<void> {
    this.updateStage(job, "validation", "processing");

    return new Promise((resolve, reject) => {
      ffmpeg.ffprobe(inputPath, (err, metadata) => {
        if (err) {
          this.updateStage(job, "validation", "failed");
          reject(new Error(`Video validation failed: ${err.message}`));
          return;
        }

        // Check if video stream exists
        const videoStream = metadata.streams.find(
          (s) => s.codec_type === "video",
        );
        if (!videoStream) {
          this.updateStage(job, "validation", "failed");
          reject(new Error("No video stream found in file"));
          return;
        }

        // Check duration
        if (metadata.format.duration! > 7200) {
          // 2 hours max
          this.updateStage(job, "validation", "failed");
          reject(new Error("Video exceeds maximum duration (2 hours)"));
          return;
        }

        this.updateStage(job, "validation", "completed", 100);
        resolve();
      });
    });
  }

  // Stage 2: Transcode video
  private async transcodeVideo(
    job: VideoProcessingJob,
    inputPath: string,
    options: VideoProcessingOptions,
  ): Promise<string> {
    this.updateStage(job, "transcoding", "processing");

    const outputPath = inputPath.replace(
      path.extname(inputPath),
      `_processed.${options.format}`,
    );

    const settings = this.getTranscodingSettings(options);

    return new Promise((resolve, reject) => {
      let command = ffmpeg(inputPath);

      // Apply video codec
      command = command.videoCodec(settings.videoCodec);

      // Apply resolution
      if (settings.resolution) {
        command = command.size(settings.resolution);
      }

      // Apply bitrate
      if (settings.videoBitrate) {
        command = command.videoBitrate(settings.videoBitrate);
      }

      // Apply FPS
      if (settings.fps) {
        command = command.fps(settings.fps);
      }

      // Apply audio codec
      command = command.audioCodec(settings.audioCodec);

      // Apply audio bitrate
      if (settings.audioBitrate) {
        command = command.audioBitrate(settings.audioBitrate);
      }

      // Apply watermark if specified
      if (options.applyWatermark && options.watermarkPath) {
        command = command.input(options.watermarkPath).complexFilter([
          {
            filter: "overlay",
            options: { x: "W-w-10", y: "H-h-10" },
          },
        ]);
      }

      // Video filters
      const filters: string[] = [];

      // Stabilization
      if (options.stabilization) {
        filters.push("deshake");
      }

      // Color correction
      if (options.colorCorrection) {
        filters.push("eq=contrast=1.1:brightness=0.05:saturation=1.1");
      }

      if (filters.length > 0) {
        command = command.videoFilters(filters);
      }

      // Track progress
      command = command.on("progress", (progress) => {
        const percent = Math.min(
          Math.round((progress.percent || 0) * 0.9),
          90,
        );
        this.updateStage(job, "transcoding", "processing", percent);
        job.progress = percent * 0.5; // Transcoding is 50% of total
        this.emit("progress", job);
      });

      command
        .on("end", () => {
          this.updateStage(job, "transcoding", "completed", 100);
          resolve(outputPath);
        })
        .on("error", (err) => {
          this.updateStage(job, "transcoding", "failed");
          reject(new Error(`Transcoding failed: ${err.message}`));
        })
        .save(outputPath);
    });
  }

  // Get transcoding settings based on quality
  private getTranscodingSettings(options: VideoProcessingOptions): any {
    const presets: Record<string, any> = {
      "720p": {
        resolution: "1280x720",
        videoBitrate: "2500k",
        videoCodec: "libx264",
        audioBitrate: "128k",
        audioCodec: "aac",
        fps: 30,
      },
      "1080p": {
        resolution: "1920x1080",
        videoBitrate: "5000k",
        videoCodec: "libx264",
        audioBitrate: "192k",
        audioCodec: "aac",
        fps: 30,
      },
      "4K": {
        resolution: "3840x2160",
        videoBitrate: "20000k",
        videoCodec: "libx265",
        audioBitrate: "256k",
        audioCodec: "aac",
        fps: 60,
      },
    };

    const preset = presets[options.quality];

    return {
      ...preset,
      videoBitrate: options.bitrate
        ? `${options.bitrate}k`
        : preset.videoBitrate,
      fps: options.fps || preset.fps,
      videoCodec: options.codec || preset.videoCodec,
    };
  }

  // Stage 3: Generate thumbnail
  private async generateThumbnail(
    job: VideoProcessingJob,
    videoPath: string,
  ): Promise<string> {
    this.updateStage(job, "thumbnail", "processing");

    const thumbnailPath = videoPath.replace(
      path.extname(videoPath),
      "_thumb.jpg",
    );

    return new Promise((resolve, reject) => {
      ffmpeg(videoPath)
        .screenshots({
          timestamps: ["10%"],
          filename: path.basename(thumbnailPath),
          folder: path.dirname(thumbnailPath),
          size: "1280x720",
        })
        .on("end", () => {
          this.updateStage(job, "thumbnail", "completed", 100);
          job.progress = 70; // Thumbnail complete
          this.emit("progress", job);
          resolve(thumbnailPath);
        })
        .on("error", (err) => {
          this.updateStage(job, "thumbnail", "failed");
          reject(new Error(`Thumbnail generation failed: ${err.message}`));
        });
    });
  }

  // Stage 4: Process audio
  private async processAudio(
    job: VideoProcessingJob,
    videoPath: string,
    options: VideoProcessingOptions,
  ): Promise<string | undefined> {
    this.updateStage(job, "audio_processing", "processing");

    if (!options.normalizeAudio && !options.extractAudio) {
      this.updateStage(job, "audio_processing", "completed", 100);
      return undefined;
    }

    const audioPath = videoPath.replace(path.extname(videoPath), ".mp3");

    return new Promise((resolve, reject) => {
      let command = ffmpeg(videoPath);

      if (options.normalizeAudio) {
        command = command.audioFilters("loudnorm");
      }

      command
        .outputOptions(["-vn"]) // No video
        .audioCodec("libmp3lame")
        .audioBitrate("192k")
        .on("end", () => {
          this.updateStage(job, "audio_processing", "completed", 100);
          job.progress = 80;
          this.emit("progress", job);
          resolve(audioPath);
        })
        .on("error", (err) => {
          this.updateStage(job, "audio_processing", "failed");
          reject(new Error(`Audio processing failed: ${err.message}`));
        })
        .save(audioPath);
    });
  }

  // Stage 5: Upload to cloud
  private async uploadToCloud(
    job: VideoProcessingJob,
    videoPath: string,
    thumbnailPath?: string,
  ): Promise<string> {
    this.updateStage(job, "upload", "processing");

    try {
      // Upload video
      const videoKey = `recordings/${job.userId}/${path.basename(videoPath)}`;
      const videoBuffer = await fs.promises.readFile(videoPath);

      await this.s3Client.send(
        new PutObjectCommand({
          Bucket: process.env.AWS_S3_BUCKET_RECORDINGS!,
          Key: videoKey,
          Body: videoBuffer,
          ContentType: this.getContentType(videoPath),
          ServerSideEncryption: "AES256",
        }),
      );

      const videoUrl = `https://${process.env.AWS_S3_BUCKET_RECORDINGS}.s3.${process.env.AWS_REGION}.amazonaws.com/${videoKey}`;

      // Upload thumbnail if exists
      if (thumbnailPath && fs.existsSync(thumbnailPath)) {
        const thumbKey = `thumbnails/${job.userId}/${path.basename(thumbnailPath)}`;
        const thumbBuffer = await fs.promises.readFile(thumbnailPath);

        await this.s3Client.send(
          new PutObjectCommand({
            Bucket: process.env.AWS_S3_BUCKET_RECORDINGS!,
            Key: thumbKey,
            Body: thumbBuffer,
            ContentType: "image/jpeg",
            ServerSideEncryption: "AES256",
          }),
        );
      }

      this.updateStage(job, "upload", "completed", 100);
      job.progress = 100;
      this.emit("progress", job);

      return videoUrl;
    } catch (error: any) {
      this.updateStage(job, "upload", "failed");
      throw new Error(`Upload failed: ${error.message}`);
    }
  }

  // Update recording in database
  private async updateRecordingInDatabase(
    recordingId: string,
    cloudUrl: string,
    thumbnailPath?: string,
    processedPath?: string,
  ): Promise<void> {
    const fileStats = processedPath
      ? await fs.promises.stat(processedPath)
      : null;

    await prisma.recording.update({
      where: { id: recordingId },
      data: {
        cloudUrl,
        thumbnailUrl: thumbnailPath
          ? thumbnailPath.replace(processedPath || "", cloudUrl)
          : undefined,
        status: "completed",
        fileSize: fileStats ? BigInt(fileStats.size) : undefined,
        metadata: {
          processed: true,
          processedAt: new Date().toISOString(),
        },
      },
    });
  }

  // Cleanup temporary files
  private async cleanup(...paths: string[]): Promise<void> {
    for (const filePath of paths) {
      try {
        if (fs.existsSync(filePath)) {
          await fs.promises.unlink(filePath);
        }
      } catch (error) {
        console.error(`Failed to delete ${filePath}:`, error);
      }
    }
  }

  // Helper: Update stage
  private updateStage(
    job: VideoProcessingJob,
    stageName: string,
    status: ProcessingStage["status"],
    progress: number = 0,
  ): void {
    const stage = job.stages.find((s) => s.name === stageName);
    if (stage) {
      stage.status = status;
      stage.progress = progress;
      if (status === "processing" && !stage.startTime) {
        stage.startTime = new Date();
      }
      if (
        (status === "completed" || status === "failed") &&
        !stage.endTime
      ) {
        stage.endTime = new Date();
      }
    }
  }

  // Helper: Get content type
  private getContentType(filePath: string): string {
    const ext = path.extname(filePath).toLowerCase();
    const types: Record<string, string> = {
      ".mp4": "video/mp4",
      ".mov": "video/quicktime",
      ".webm": "video/webm",
      ".avi": "video/x-msvideo",
    };
    return types[ext] || "application/octet-stream";
  }

  // Get job status
  getJobStatus(jobId: string): VideoProcessingJob | undefined {
    return this.activeJobs.get(jobId);
  }

  // Get all active jobs for user
  getUserJobs(userId: string): VideoProcessingJob[] {
    return Array.from(this.activeJobs.values()).filter(
      (job) => job.userId === userId,
    );
  }

  // Cancel job
  async cancelJob(jobId: string): Promise<void> {
    const job = this.activeJobs.get(jobId);
    if (job) {
      job.status = "failed";
      job.error = "Cancelled by user";
      this.activeJobs.delete(jobId);
      this.emit("job_cancelled", job);
    }
  }
}

export const videoProcessingService = new VideoProcessingService();
