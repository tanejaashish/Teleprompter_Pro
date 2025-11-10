// AI Service Helper Methods
// Implementations for missing methods in advanced-ai-service.ts

import * as tf from "@tensorflow/tfjs-node";
import ffmpeg from "fluent-ffmpeg";
import { promisify } from "util";
import { exec } from "child_process";
import fs from "fs";
import path from "path";

const execAsync = promisify(exec);

export class AIHelperMethods {
  // Extract title from generated script
  extractTitle(script: string): string {
    // Try to find a title in markdown format
    const titleMatch = script.match(/^#\s+(.+)$/m);
    if (titleMatch) {
      return titleMatch[1].trim();
    }

    // Try to find title in first line
    const firstLine = script.split("\n")[0].trim();
    if (firstLine.length > 0 && firstLine.length < 100) {
      return firstLine.replace(/^[#*]+\s*/, "");
    }

    // Generate title from first few words
    const words = script.split(/\s+/).slice(0, 5);
    return words.join(" ") + "...";
  }

  // Track AI usage for billing
  async trackUsage(
    userId: string,
    model: string,
    wordCount: number,
  ): Promise<void> {
    const { PrismaClient } = require("@prisma/client");
    const prisma = new PrismaClient();

    const billingPeriod = new Date().toISOString().slice(0, 7); // YYYY-MM

    await prisma.usageRecord.create({
      data: {
        userId,
        resourceType: "ai_generation",
        resourceId: model,
        quantity: wordCount,
        unit: "words",
        billingPeriod,
        description: `AI script generation using ${model}`,
        metadata: {
          model,
          timestamp: new Date().toISOString(),
        },
      },
    });
  }

  // Build system prompt for AI
  buildSystemPrompt(style: string, audience: string): string {
    const basePrompt =
      "You are a professional teleprompter script writer. Create engaging, natural-sounding scripts that are easy to read aloud.";

    const stylePrompts: Record<string, string> = {
      professional:
        "Write in a formal, authoritative tone suitable for business presentations.",
      casual:
        "Write in a friendly, conversational tone as if talking to a friend.",
      educational:
        "Write in a clear, informative tone suitable for teaching and explaining concepts.",
      persuasive:
        "Write in a compelling, convincing tone to motivate and inspire action.",
      storytelling:
        "Write in an engaging, narrative style that captivates the audience.",
    };

    const audiencePrompts: Record<string, string> = {
      general: "The audience is general public with varied backgrounds.",
      technical:
        "The audience is technical professionals familiar with industry jargon.",
      executives:
        "The audience is business executives who value concise, strategic content.",
      students:
        "The audience is students who benefit from clear explanations and examples.",
      customers:
        "The audience is potential customers interested in products/services.",
    };

    return `${basePrompt}

Style: ${stylePrompts[style] || stylePrompts.professional}
Audience: ${audiencePrompts[audience] || audiencePrompts.general}

Format the script with:
- Clear section breaks
- Pause markers where natural pauses should occur
- Emphasis on key words or phrases
- Easy-to-read formatting for teleprompter display`;
  }

  // Identify keywords for emphasis
  async identifyKeywords(text: string): Promise<string[]> {
    // Simple keyword extraction based on frequency and importance
    const words = text
      .toLowerCase()
      .split(/\W+/)
      .filter((w) => w.length > 3);

    // Remove common words
    const commonWords = new Set([
      "this",
      "that",
      "with",
      "from",
      "have",
      "been",
      "were",
      "they",
      "will",
      "would",
      "could",
      "should",
      "about",
      "which",
      "their",
      "there",
      "these",
      "those",
    ]);

    const filtered = words.filter((w) => !commonWords.has(w));

    // Count frequency
    const frequency: Record<string, number> = {};
    filtered.forEach((word) => {
      frequency[word] = (frequency[word] || 0) + 1;
    });

    // Return top keywords
    return Object.entries(frequency)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([word]) => word);
  }

  // Extract frames from video
  async extractFrames(videoPath: string): Promise<string[]> {
    const tempDir = path.join("/tmp", `frames_${Date.now()}`);
    await fs.promises.mkdir(tempDir, { recursive: true });

    return new Promise((resolve, reject) => {
      ffmpeg(videoPath)
        .outputOptions(["-vf fps=30"]) // 30 fps
        .output(path.join(tempDir, "frame_%04d.png"))
        .on("end", async () => {
          const files = await fs.promises.readdir(tempDir);
          const framePaths = files
            .filter((f) => f.endsWith(".png"))
            .map((f) => path.join(tempDir, f))
            .sort();
          resolve(framePaths);
        })
        .on("error", reject)
        .run();
    });
  }

  // Detect face in image tensor
  async detectFace(
    imageTensor: tf.Tensor,
  ): Promise<{ detected: boolean; landmarks?: any }> {
    // Placeholder for face detection
    // In production, use @mediapipe/face_detection or similar
    try {
      // Simulate face detection
      const imageData = imageTensor.arraySync();

      // Simple brightness-based detection (placeholder)
      // Replace with actual face detection model
      const avgBrightness =
        imageTensor.mean().arraySync() as number;

      return {
        detected: avgBrightness > 0.2, // Placeholder logic
        landmarks: {
          leftEye: { x: 0.3, y: 0.4 },
          rightEye: { x: 0.7, y: 0.4 },
          nose: { x: 0.5, y: 0.6 },
          mouth: { x: 0.5, y: 0.8 },
        },
      };
    } catch (error) {
      console.error("Face detection error:", error);
      return { detected: false };
    }
  }

  // Reconstruct video from frames
  async reconstructVideo(
    framePaths: string[],
    outputPath: string,
    fps: number = 30,
  ): Promise<void> {
    const framePattern = path.join(
      path.dirname(framePaths[0]),
      "frame_%04d.png",
    );

    return new Promise((resolve, reject) => {
      ffmpeg()
        .input(framePattern)
        .inputFPS(fps)
        .outputOptions([
          "-c:v libx264",
          "-pix_fmt yuv420p",
          "-preset medium",
          "-crf 23",
        ])
        .output(outputPath)
        .on("end", () => resolve())
        .on("error", reject)
        .run();
    });
  }

  // Additional helper: Extract audio from video
  async extractAudio(videoPath: string): Promise<string> {
    const audioPath = videoPath.replace(
      path.extname(videoPath),
      ".wav",
    );

    return new Promise((resolve, reject) => {
      ffmpeg(videoPath)
        .outputOptions([
          "-vn", // No video
          "-acodec pcm_s16le", // Audio codec
          "-ar 16000", // Sample rate for Whisper
          "-ac 1", // Mono
        ])
        .output(audioPath)
        .on("end", () => resolve(audioPath))
        .on("error", reject)
        .run();
    });
  }

  // Load image as tensor
  async loadImageAsTensor(imagePath: string): Promise<tf.Tensor> {
    const imageBuffer = await fs.promises.readFile(imagePath);
    const tfimage = tf.node.decodeImage(imageBuffer, 3);
    return tfimage;
  }

  // Save tensor as image
  async saveTensor(tensor: tf.Tensor, index: number): Promise<string> {
    const tempDir = "/tmp/corrected_frames";
    await fs.promises.mkdir(tempDir, { recursive: true });

    const outputPath = path.join(
      tempDir,
      `frame_${String(index).padStart(4, "0")}.png",
    );

    const encoded = await tf.node.encodePng(tensor as tf.Tensor3D);
    await fs.promises.writeFile(outputPath, encoded);

    return outputPath;
  }

  // Cleanup temporary files
  async cleanupTempFiles(filePaths: string[]): Promise<void> {
    for (const filePath of filePaths) {
      try {
        await fs.promises.unlink(filePath);
      } catch (error) {
        console.error(`Failed to delete ${filePath}:`, error);
      }
    }

    // Also cleanup temp directories
    const dirs = new Set(filePaths.map((f) => path.dirname(f)));
    for (const dir of dirs) {
      try {
        await fs.promises.rmdir(dir);
      } catch (error) {
        // Directory might not be empty or already deleted
      }
    }
  }
}

export const aiHelpers = new AIHelperMethods();
