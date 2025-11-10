// Voice-Activated Scrolling Service
// Implements real-time voice tracking for automatic scroll control

import { PrismaClient } from "@prisma/client";
import OpenAI from "openai";
import { EventEmitter } from "events";

const prisma = new PrismaClient();
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export interface VoiceScrollConfig {
  userId: string;
  scriptId: string;
  scriptContent: string;
  sensitivity: number; // 0.1 to 1.0
  language: string;
  autoAdjustSpeed: boolean;
}

export interface ScrollPosition {
  characterPosition: number;
  wordPosition: number;
  lineNumber: number;
  scrollPercentage: number;
  confidence: number;
}

export class VoiceScrollingService extends EventEmitter {
  private activeSession: Map<
    string,
    {
      config: VoiceScrollConfig;
      currentPosition: number;
      buffer: string[];
      lastUpdate: number;
    }
  > = new Map();

  // Start voice scrolling session
  async startSession(config: VoiceScrollConfig): Promise<string> {
    const sessionId = `voice_scroll_${config.userId}_${Date.now()}`;

    this.activeSession.set(sessionId, {
      config,
      currentPosition: 0,
      buffer: [],
      lastUpdate: Date.now(),
    });

    // Initialize session in database
    await prisma.activity.create({
      data: {
        userId: config.userId,
        type: "voice_scroll_started",
        action: "create",
        entityType: "script",
        entityId: config.scriptId,
        metadata: {
          sessionId,
          language: config.language,
        },
      },
    });

    return sessionId;
  }

  // Process audio chunk and return scroll position
  async processAudioChunk(
    sessionId: string,
    audioBuffer: Buffer,
  ): Promise<ScrollPosition | null> {
    const session = this.activeSession.get(sessionId);
    if (!session) {
      throw new Error("Session not found");
    }

    try {
      // Transcribe audio using Whisper
      const transcription = await this.transcribeAudio(
        audioBuffer,
        session.config.language,
      );

      if (!transcription || transcription.trim().length === 0) {
        return null;
      }

      // Add to buffer for context
      session.buffer.push(transcription);
      if (session.buffer.length > 10) {
        session.buffer.shift(); // Keep last 10 chunks
      }

      // Find position in script
      const position = this.findPositionInScript(
        session.config.scriptContent,
        transcription,
        session.currentPosition,
      );

      if (position) {
        session.currentPosition = position.characterPosition;
        session.lastUpdate = Date.now();

        // Emit event for real-time updates
        this.emit("position_update", {
          sessionId,
          position,
          transcription,
        });

        // Auto-adjust speed if enabled
        if (session.config.autoAdjustSpeed) {
          await this.adjustScrollSpeed(sessionId, position);
        }

        return position;
      }

      return null;
    } catch (error) {
      console.error("Error processing audio chunk:", error);
      this.emit("error", { sessionId, error });
      return null;
    }
  }

  // Transcribe audio using OpenAI Whisper
  private async transcribeAudio(
    audioBuffer: Buffer,
    language: string,
  ): Promise<string> {
    try {
      // Create a temporary file from buffer
      const fs = require("fs");
      const path = require("path");
      const tempPath = path.join(
        "/tmp",
        `audio_${Date.now()}.wav`,
      );

      await fs.promises.writeFile(tempPath, audioBuffer);

      // Transcribe with Whisper
      const transcription =
        await openai.audio.transcriptions.create({
          file: fs.createReadStream(tempPath),
          model: "whisper-1",
          language: language || "en",
          response_format: "text",
        });

      // Cleanup temp file
      await fs.promises.unlink(tempPath);

      return (transcription as any).text || transcription;
    } catch (error) {
      console.error("Transcription error:", error);
      throw error;
    }
  }

  // Find position in script using fuzzy matching
  private findPositionInScript(
    scriptContent: string,
    spokenText: string,
    currentPosition: number,
  ): ScrollPosition | null {
    // Clean and normalize text
    const cleanScript = this.cleanText(scriptContent);
    const cleanSpoken = this.cleanText(spokenText);

    // Search window: look ahead from current position
    const searchStart = Math.max(0, currentPosition - 100);
    const searchEnd = Math.min(
      cleanScript.length,
      currentPosition + 500,
    );
    const searchWindow = cleanScript.substring(
      searchStart,
      searchEnd,
    );

    // Find best match using fuzzy search
    const match = this.fuzzyMatch(searchWindow, cleanSpoken);

    if (match && match.score > 0.6) {
      const absolutePosition = searchStart + match.position;

      return {
        characterPosition: absolutePosition,
        wordPosition: this.countWords(
          cleanScript.substring(0, absolutePosition),
        ),
        lineNumber: this.countLines(
          scriptContent.substring(0, absolutePosition),
        ),
        scrollPercentage:
          (absolutePosition / cleanScript.length) * 100,
        confidence: match.score,
      };
    }

    return null;
  }

  // Fuzzy matching algorithm
  private fuzzyMatch(
    text: string,
    pattern: string,
  ): { position: number; score: number } | null {
    const words = pattern.split(/\s+/);
    let bestMatch: { position: number; score: number } | null =
      null;

    for (let i = 0; i < text.length - pattern.length; i++) {
      const window = text.substring(i, i + pattern.length * 2);
      const score = this.calculateSimilarity(window, pattern);

      if (!bestMatch || score > bestMatch.score) {
        bestMatch = { position: i, score };
      }
    }

    return bestMatch;
  }

  // Calculate text similarity (Levenshtein distance based)
  private calculateSimilarity(text1: string, text2: string): number {
    const matrix: number[][] = [];

    for (let i = 0; i <= text2.length; i++) {
      matrix[i] = [i];
    }

    for (let j = 0; j <= text1.length; j++) {
      matrix[0][j] = j;
    }

    for (let i = 1; i <= text2.length; i++) {
      for (let j = 1; j <= text1.length; j++) {
        if (text2.charAt(i - 1) === text1.charAt(j - 1)) {
          matrix[i][j] = matrix[i - 1][j - 1];
        } else {
          matrix[i][j] = Math.min(
            matrix[i - 1][j - 1] + 1,
            matrix[i][j - 1] + 1,
            matrix[i - 1][j] + 1,
          );
        }
      }
    }

    const distance = matrix[text2.length][text1.length];
    const maxLength = Math.max(text1.length, text2.length);
    return 1 - distance / maxLength;
  }

  // Clean text for comparison
  private cleanText(text: string): string {
    return text
      .toLowerCase()
      .replace(/[^\w\s]/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  // Count words
  private countWords(text: string): number {
    return text.split(/\s+/).filter((w) => w.length > 0).length;
  }

  // Count lines
  private countLines(text: string): number {
    return text.split("\n").length;
  }

  // Auto-adjust scroll speed based on speaking rate
  private async adjustScrollSpeed(
    sessionId: string,
    position: ScrollPosition,
  ): Promise<void> {
    const session = this.activeSession.get(sessionId);
    if (!session) return;

    const timeDelta = Date.now() - session.lastUpdate;
    const positionDelta =
      position.characterPosition - session.currentPosition;

    if (timeDelta > 0 && positionDelta > 0) {
      const charsPerSecond = (positionDelta / timeDelta) * 1000;
      const wordsPerMinute = (charsPerSecond * 60) / 5; // Average 5 chars per word

      // Emit speed recommendation
      this.emit("speed_adjustment", {
        sessionId,
        recommendedWPM: Math.round(wordsPerMinute),
        charsPerSecond,
      });
    }
  }

  // Stop session
  async stopSession(sessionId: string): Promise<void> {
    const session = this.activeSession.get(sessionId);
    if (!session) return;

    // Log session end
    await prisma.activity.create({
      data: {
        userId: session.config.userId,
        type: "voice_scroll_ended",
        action: "create",
        entityType: "script",
        entityId: session.config.scriptId,
        metadata: {
          sessionId,
          duration: Date.now() - session.lastUpdate,
          finalPosition: session.currentPosition,
        },
      },
    });

    this.activeSession.delete(sessionId);
    this.emit("session_ended", { sessionId });
  }

  // Get session stats
  getSessionStats(sessionId: string): any {
    const session = this.activeSession.get(sessionId);
    if (!session) return null;

    return {
      sessionId,
      currentPosition: session.currentPosition,
      scrollPercentage:
        (session.currentPosition /
          session.config.scriptContent.length) *
        100,
      bufferSize: session.buffer.length,
      lastUpdate: session.lastUpdate,
      active: Date.now() - session.lastUpdate < 5000, // Active if updated in last 5s
    };
  }
}

export const voiceScrollService = new VoiceScrollingService();
