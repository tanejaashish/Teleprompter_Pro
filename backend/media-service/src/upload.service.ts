import AWS from "aws-sdk";
import multer from "multer";
import multerS3 from "multer-s3";

const s3 = new AWS.S3({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION,
});

export const uploadService = multer({
  storage: multerS3({
    s3,
    bucket: process.env.S3_BUCKET_NAME!,
    metadata: (req, file, cb) => {
      cb(null, { fieldName: file.fieldname });
    },
    key: (req, file, cb) => {
      const userId = (req as any).user.id;
      const timestamp = Date.now();
      cb(null, `recordings/${userId}/${timestamp}-${file.originalname}`);
    },
  }),
  limits: {
    fileSize: 5 * 1024 * 1024 * 1024, // 5GB limit for Pro users
  },
});
