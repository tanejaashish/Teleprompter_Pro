import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";
import ffmpeg from "fluent-ffmpeg";

const sqsClient = new SQSClient({ region: process.env.AWS_REGION });

export class VideoProcessor {
  async processVideo(inputPath: string, outputSettings: any) {
    // Add to processing queue
    await sqsClient.send(
      new SendMessageCommand({
        QueueUrl: process.env.VIDEO_PROCESSING_QUEUE_URL!,
        MessageBody: JSON.stringify({
          inputPath,
          outputSettings,
          timestamp: new Date().toISOString(),
        }),
      }),
    );
  }

  async transcodeVideo(input: string, output: string, quality: string) {
    return new Promise((resolve, reject) => {
      ffmpeg(input)
        .outputOptions([
          "-c:v libx264",
          "-preset medium",
          "-crf 23",
          "-c:a aac",
          "-b:a 128k",
        ])
        .output(output)
        .on("end", resolve)
        .on("error", reject)
        .run();
    });
  }
}
