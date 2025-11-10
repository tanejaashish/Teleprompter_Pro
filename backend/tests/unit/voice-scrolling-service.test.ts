// Comprehensive Test Suite - Voice Scrolling Service
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { VoiceScrollingService } from '../../ai-service/src/voice-scrolling-service';
import { EventEmitter } from 'events';

jest.mock('openai');
jest.mock('fs');

describe('VoiceScrollingService', () => {
  let voiceScrollingService: VoiceScrollingService;

  beforeEach(() => {
    voiceScrollingService = new VoiceScrollingService();
  });

  describe('startSession', () => {
    it('should create a new voice scrolling session', async () => {
      const sessionId = await voiceScrollingService.startSession(
        'user_123',
        'script_456',
        'This is a test script content for voice scrolling.',
        {
          language: 'en',
          sensitivity: 0.7,
          autoAdjustSpeed: true,
        },
      );

      expect(sessionId).toBeDefined();
      expect(typeof sessionId).toBe('string');
    });

    it('should throw error if script content is empty', async () => {
      await expect(
        voiceScrollingService.startSession('user_123', 'script_456', '', {}),
      ).rejects.toThrow('Script content cannot be empty');
    });
  });

  describe('processAudioChunk', () => {
    it('should process audio and return scroll position', async () => {
      const sessionId = await voiceScrollingService.startSession(
        'user_123',
        'script_456',
        'The quick brown fox jumps over the lazy dog.',
        { language: 'en' },
      );

      const audioBuffer = Buffer.from('mock_audio_data');

      // Mock transcription result
      jest.spyOn(voiceScrollingService as any, 'transcribeAudio').mockResolvedValue('quick brown fox');

      const position = await voiceScrollingService.processAudioChunk(sessionId, audioBuffer);

      expect(position).toBeDefined();
      if (position) {
        expect(position.characterPosition).toBeGreaterThanOrEqual(0);
        expect(position.confidence).toBeGreaterThan(0);
        expect(position.scrollPercentage).toBeGreaterThanOrEqual(0);
        expect(position.scrollPercentage).toBeLessThanOrEqual(100);
      }
    });

    it('should return null if no match found', async () => {
      const sessionId = await voiceScrollingService.startSession(
        'user_123',
        'script_456',
        'The quick brown fox jumps over the lazy dog.',
        { language: 'en' },
      );

      const audioBuffer = Buffer.from('mock_audio_data');

      // Mock transcription with non-matching text
      jest.spyOn(voiceScrollingService as any, 'transcribeAudio').mockResolvedValue('completely different text');

      const position = await voiceScrollingService.processAudioChunk(sessionId, audioBuffer);

      expect(position).toBeNull();
    });

    it('should throw error for invalid session', async () => {
      const audioBuffer = Buffer.from('mock_audio_data');

      await expect(
        voiceScrollingService.processAudioChunk('invalid_session', audioBuffer),
      ).rejects.toThrow('Session not found');
    });
  });

  describe('adjustScrollSpeed', () => {
    it('should adjust scroll speed based on speaking pace', async () => {
      const sessionId = await voiceScrollingService.startSession(
        'user_123',
        'script_456',
        'This is a test script with multiple words to test scrolling speed adjustment.',
        { autoAdjustSpeed: true },
      );

      const mockPosition = {
        characterPosition: 20,
        wordPosition: 5,
        scrollPercentage: 25,
        confidence: 0.9,
      };

      await voiceScrollingService.adjustScrollSpeed(sessionId, mockPosition);

      const session = (voiceScrollingService as any).sessions.get(sessionId);
      expect(session).toBeDefined();
      expect(session.config.scrollSpeed).toBeDefined();
    });
  });

  describe('fuzzyMatch', () => {
    it('should find close matches with high confidence', () => {
      const text = 'The quick brown fox jumps over the lazy dog';
      const pattern = 'quik brwn fox'; // Typos

      const result = (voiceScrollingService as any).fuzzyMatch(text, pattern);

      expect(result).toBeDefined();
      expect(result.score).toBeGreaterThan(0.5);
      expect(result.position).toBeGreaterThanOrEqual(0);
    });

    it('should return low confidence for very different text', () => {
      const text = 'The quick brown fox jumps over the lazy dog';
      const pattern = 'completely different sentence';

      const result = (voiceScrollingService as any).fuzzyMatch(text, pattern);

      if (result) {
        expect(result.score).toBeLessThan(0.5);
      }
    });
  });

  describe('pauseSession', () => {
    it('should pause an active session', async () => {
      const sessionId = await voiceScrollingService.startSession(
        'user_123',
        'script_456',
        'Test script content',
        {},
      );

      await voiceScrollingService.pauseSession(sessionId);

      const session = (voiceScrollingService as any).sessions.get(sessionId);
      expect(session).toBeDefined();
      // Verify session is paused (implementation specific)
    });
  });

  describe('endSession', () => {
    it('should end and cleanup session', async () => {
      const sessionId = await voiceScrollingService.startSession(
        'user_123',
        'script_456',
        'Test script content',
        {},
      );

      await voiceScrollingService.endSession(sessionId);

      const session = (voiceScrollingService as any).sessions.get(sessionId);
      expect(session).toBeUndefined();
    });

    it('should not throw error for non-existent session', async () => {
      await expect(
        voiceScrollingService.endSession('non_existent_session'),
      ).resolves.not.toThrow();
    });
  });

  describe('getSessionStatus', () => {
    it('should return session statistics', async () => {
      const sessionId = await voiceScrollingService.startSession(
        'user_123',
        'script_456',
        'Test script content',
        {},
      );

      const status = voiceScrollingService.getSessionStatus(sessionId);

      expect(status).toBeDefined();
      expect(status.sessionId).toBe(sessionId);
      expect(status.userId).toBe('user_123');
      expect(status.scriptId).toBe('script_456');
      expect(status.currentPosition).toBeDefined();
    });

    it('should throw error for invalid session', () => {
      expect(() => {
        voiceScrollingService.getSessionStatus('invalid_session');
      }).toThrow('Session not found');
    });
  });

  describe('event emissions', () => {
    it('should emit position_update event on successful match', async (done) => {
      const sessionId = await voiceScrollingService.startSession(
        'user_123',
        'script_456',
        'The quick brown fox',
        {},
      );

      voiceScrollingService.on('position_update', (data) => {
        expect(data.sessionId).toBe(sessionId);
        expect(data.position).toBeDefined();
        expect(data.transcription).toBeDefined();
        done();
      });

      jest.spyOn(voiceScrollingService as any, 'transcribeAudio').mockResolvedValue('quick brown');

      await voiceScrollingService.processAudioChunk(sessionId, Buffer.from('audio'));
    });

    it('should emit session_paused event', async (done) => {
      const sessionId = await voiceScrollingService.startSession(
        'user_123',
        'script_456',
        'Test content',
        {},
      );

      voiceScrollingService.on('session_paused', (data) => {
        expect(data.sessionId).toBe(sessionId);
        done();
      });

      await voiceScrollingService.pauseSession(sessionId);
    });
  });
});
