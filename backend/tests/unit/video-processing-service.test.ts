// Comprehensive Test Suite - Video Processing Service
import { describe, it, expect, beforeEach, jest, afterEach } from '@jest/globals';
import { VideoProcessingService } from '../../media-service/src/video-processing-service';
import * as fs from 'fs';
import * as path from 'path';

jest.mock('fluent-ffmpeg');
jest.mock('@aws-sdk/client-s3');
jest.mock('@aws-sdk/lib-storage');
jest.mock('fs');

describe('VideoProcessingService', () => {
  let videoProcessingService: VideoProcessingService;
  const mockInputPath = '/tmp/test-video.mp4';
  const mockOutputPath = '/tmp/test-video-processed.mp4';

  beforeEach(() => {
    videoProcessingService = new VideoProcessingService();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('processVideo', () => {
    it('should process video through all stages', async () => {
      const options = {
        quality: '1080p' as const,
        format: 'mp4' as const,
        removeBackground: false,
        stabilize: false,
        colorCorrection: false,
      };

      // Mock file system operations
      jest.spyOn(fs.promises, 'access').mockResolvedValue(undefined);
      jest.spyOn(fs.promises, 'stat').mockResolvedValue({ size: 1024 * 1024 * 100 } as any);
      jest.spyOn(fs.promises, 'unlink').mockResolvedValue(undefined);

      // Mock video processing stages
      jest.spyOn(videoProcessingService as any, 'validateVideo').mockResolvedValue(undefined);
      jest.spyOn(videoProcessingService as any, 'transcodeVideo').mockResolvedValue(mockOutputPath);
      jest.spyOn(videoProcessingService as any, 'generateThumbnail').mockResolvedValue('/tmp/thumb.jpg');
      jest.spyOn(videoProcessingService as any, 'processAudio').mockResolvedValue(undefined);
      jest.spyOn(videoProcessingService as any, 'uploadToCloud').mockResolvedValue('https://cdn.example.com/video.mp4');

      const result = await videoProcessingService.processVideo(
        'user_123',
        'recording_456',
        mockInputPath,
        options,
      );

      expect(result).toBe('https://cdn.example.com/video.mp4');
    });

    it('should throw error for invalid video file', async () => {
      jest.spyOn(fs.promises, 'access').mockRejectedValue(new Error('File not found'));

      const options = {
        quality: '1080p' as const,
        format: 'mp4' as const,
      };

      await expect(
        videoProcessingService.processVideo('user_123', 'recording_456', 'invalid.mp4', options),
      ).rejects.toThrow();
    });

    it('should emit progress events during processing', async (done) => {
      const options = {
        quality: '720p' as const,
        format: 'mp4' as const,
      };

      jest.spyOn(fs.promises, 'access').mockResolvedValue(undefined);
      jest.spyOn(fs.promises, 'stat').mockResolvedValue({ size: 1024 * 1024 * 50 } as any);
      jest.spyOn(videoProcessingService as any, 'validateVideo').mockResolvedValue(undefined);
      jest.spyOn(videoProcessingService as any, 'transcodeVideo').mockResolvedValue(mockOutputPath);
      jest.spyOn(videoProcessingService as any, 'generateThumbnail').mockResolvedValue('/tmp/thumb.jpg');
      jest.spyOn(videoProcessingService as any, 'processAudio').mockResolvedValue(undefined);
      jest.spyOn(videoProcessingService as any, 'uploadToCloud').mockResolvedValue('https://cdn.example.com/video.mp4');

      const progressEvents: string[] = [];

      videoProcessingService.on('processing_progress', (data) => {
        progressEvents.push(data.stage);
        if (data.stage === 'upload') {
          expect(progressEvents).toContain('validation');
          expect(progressEvents).toContain('transcoding');
          done();
        }
      });

      await videoProcessingService.processVideo('user_123', 'recording_456', mockInputPath, options);
    });
  });

  describe('validateVideo', () => {
    it('should validate video file exists and has correct format', async () => {
      jest.spyOn(fs.promises, 'access').mockResolvedValue(undefined);
      jest.spyOn(fs.promises, 'stat').mockResolvedValue({
        size: 1024 * 1024 * 50,
        isFile: () => true,
      } as any);

      const mockJob = {
        id: 'job_123',
        userId: 'user_123',
        recordingId: 'recording_456',
        inputPath: mockInputPath,
        stages: [],
        progress: 0,
        status: 'processing' as const,
        startedAt: new Date(),
      };

      await expect(
        (videoProcessingService as any).validateVideo(mockJob, mockInputPath),
      ).resolves.not.toThrow();
    });

    it('should throw error for file exceeding size limit', async () => {
      jest.spyOn(fs.promises, 'access').mockResolvedValue(undefined);
      jest.spyOn(fs.promises, 'stat').mockResolvedValue({
        size: 1024 * 1024 * 1024 * 6, // 6GB, exceeds 5GB limit
        isFile: () => true,
      } as any);

      const mockJob = {
        id: 'job_123',
        stages: [],
        progress: 0,
      } as any;

      await expect(
        (videoProcessingService as any).validateVideo(mockJob, mockInputPath),
      ).rejects.toThrow('File size exceeds maximum limit');
    });

    it('should throw error for unsupported format', async () => {
      const invalidPath = '/tmp/test.avi';

      jest.spyOn(fs.promises, 'access').mockResolvedValue(undefined);
      jest.spyOn(fs.promises, 'stat').mockResolvedValue({
        size: 1024 * 1024 * 50,
        isFile: () => true,
      } as any);

      const mockJob = {
        id: 'job_123',
        stages: [],
        progress: 0,
      } as any;

      await expect(
        (videoProcessingService as any).validateVideo(mockJob, invalidPath),
      ).rejects.toThrow('Unsupported video format');
    });
  });

  describe('transcodeVideo', () => {
    it('should transcode video to specified quality', async () => {
      const options = {
        quality: '1080p' as const,
        format: 'mp4' as const,
      };

      const mockJob = {
        id: 'job_123',
        stages: [],
        progress: 0,
      } as any;

      // Mock ffmpeg
      const mockFfmpeg = {
        input: jest.fn().mockReturnThis(),
        videoCodec: jest.fn().mockReturnThis(),
        audioCodec: jest.fn().mockReturnThis(),
        size: jest.fn().mockReturnThis(),
        videoBitrate: jest.fn().mockReturnThis(),
        audioBitrate: jest.fn().mockReturnThis(),
        outputOptions: jest.fn().mockReturnThis(),
        output: jest.fn().mockReturnThis(),
        on: jest.fn().mockImplementation(function(event, callback) {
          if (event === 'end') {
            callback();
          }
          return this;
        }),
        run: jest.fn(),
      };

      const ffmpegMock = jest.fn(() => mockFfmpeg);
      (videoProcessingService as any).ffmpeg = ffmpegMock;

      const result = await (videoProcessingService as any).transcodeVideo(
        mockJob,
        mockInputPath,
        options,
      );

      expect(result).toBeDefined();
      expect(mockFfmpeg.videoCodec).toHaveBeenCalled();
      expect(mockFfmpeg.run).toHaveBeenCalled();
    });

    it('should apply watermark if specified', async () => {
      const options = {
        quality: '720p' as const,
        format: 'mp4' as const,
        watermark: {
          text: 'TelePrompt Pro',
          position: 'bottom-right' as const,
          opacity: 0.5,
        },
      };

      const mockJob = { id: 'job_123', stages: [], progress: 0 } as any;

      const mockFfmpeg = {
        input: jest.fn().mockReturnThis(),
        videoCodec: jest.fn().mockReturnThis(),
        audioCodec: jest.fn().mockReturnThis(),
        size: jest.fn().mockReturnThis(),
        videoBitrate: jest.fn().mockReturnThis(),
        audioBitrate: jest.fn().mockReturnThis(),
        outputOptions: jest.fn().mockReturnThis(),
        output: jest.fn().mockReturnThis(),
        on: jest.fn().mockImplementation(function(event, callback) {
          if (event === 'end') callback();
          return this;
        }),
        run: jest.fn(),
      };

      const ffmpegMock = jest.fn(() => mockFfmpeg);
      (videoProcessingService as any).ffmpeg = ffmpegMock;

      await (videoProcessingService as any).transcodeVideo(mockJob, mockInputPath, options);

      expect(mockFfmpeg.outputOptions).toHaveBeenCalled();
    });
  });

  describe('generateThumbnail', () => {
    it('should generate thumbnail at specified timestamp', async () => {
      const mockJob = { id: 'job_123', stages: [], progress: 0 } as any;

      const mockFfmpeg = {
        input: jest.fn().mockReturnThis(),
        screenshots: jest.fn().mockReturnThis(),
        on: jest.fn().mockImplementation(function(event, callback) {
          if (event === 'end') callback();
          return this;
        }),
      };

      const ffmpegMock = jest.fn(() => mockFfmpeg);
      (videoProcessingService as any).ffmpeg = ffmpegMock;

      const thumbnailPath = await (videoProcessingService as any).generateThumbnail(
        mockJob,
        mockOutputPath,
        5,
      );

      expect(thumbnailPath).toBeDefined();
      expect(mockFfmpeg.screenshots).toHaveBeenCalled();
    });
  });

  describe('processAudio', () => {
    it('should normalize audio levels', async () => {
      const options = {
        quality: '720p' as const,
        format: 'mp4' as const,
        audioEnhancement: {
          normalize: true,
          noiseReduction: false,
        },
      };

      const mockJob = { id: 'job_123', stages: [], progress: 0 } as any;

      const mockFfmpeg = {
        input: jest.fn().mockReturnThis(),
        audioFilters: jest.fn().mockReturnThis(),
        audioCodec: jest.fn().mockReturnThis(),
        output: jest.fn().mockReturnThis(),
        on: jest.fn().mockImplementation(function(event, callback) {
          if (event === 'end') callback();
          return this;
        }),
        run: jest.fn(),
      };

      const ffmpegMock = jest.fn(() => mockFfmpeg);
      (videoProcessingService as any).ffmpeg = ffmpegMock;

      await (videoProcessingService as any).processAudio(mockJob, mockOutputPath, options);

      expect(mockFfmpeg.audioFilters).toHaveBeenCalled();
    });

    it('should apply noise reduction if specified', async () => {
      const options = {
        quality: '720p' as const,
        format: 'mp4' as const,
        audioEnhancement: {
          normalize: false,
          noiseReduction: true,
        },
      };

      const mockJob = { id: 'job_123', stages: [], progress: 0 } as any;

      const mockFfmpeg = {
        input: jest.fn().mockReturnThis(),
        audioFilters: jest.fn().mockReturnThis(),
        audioCodec: jest.fn().mockReturnThis(),
        output: jest.fn().mockReturnThis(),
        on: jest.fn().mockImplementation(function(event, callback) {
          if (event === 'end') callback();
          return this;
        }),
        run: jest.fn(),
      };

      const ffmpegMock = jest.fn(() => mockFfmpeg);
      (videoProcessingService as any).ffmpeg = ffmpegMock;

      await (videoProcessingService as any).processAudio(mockJob, mockOutputPath, options);

      expect(mockFfmpeg.audioFilters).toHaveBeenCalledWith(
        expect.stringContaining('afftdn'),
      );
    });
  });

  describe('uploadToCloud', () => {
    it('should upload video and thumbnail to S3', async () => {
      const mockJob = { id: 'job_123', stages: [], progress: 0 } as any;
      const thumbnailPath = '/tmp/thumb.jpg';

      jest.spyOn(fs, 'createReadStream').mockReturnValue({} as any);

      const mockUpload = {
        done: jest.fn().mockResolvedValue({
          Location: 'https://s3.amazonaws.com/bucket/video.mp4',
        }),
      };

      (videoProcessingService as any).s3Uploader = jest.fn(() => mockUpload);

      const result = await (videoProcessingService as any).uploadToCloud(
        mockJob,
        mockOutputPath,
        thumbnailPath,
      );

      expect(result).toBe('https://s3.amazonaws.com/bucket/video.mp4');
      expect(mockUpload.done).toHaveBeenCalled();
    });

    it('should retry upload on failure', async () => {
      const mockJob = { id: 'job_123', stages: [], progress: 0 } as any;
      const thumbnailPath = '/tmp/thumb.jpg';

      jest.spyOn(fs, 'createReadStream').mockReturnValue({} as any);

      let attemptCount = 0;
      const mockUpload = {
        done: jest.fn().mockImplementation(() => {
          attemptCount++;
          if (attemptCount < 2) {
            return Promise.reject(new Error('Network error'));
          }
          return Promise.resolve({
            Location: 'https://s3.amazonaws.com/bucket/video.mp4',
          });
        }),
      };

      (videoProcessingService as any).s3Uploader = jest.fn(() => mockUpload);
      (videoProcessingService as any).MAX_UPLOAD_RETRIES = 3;

      const result = await (videoProcessingService as any).uploadToCloud(
        mockJob,
        mockOutputPath,
        thumbnailPath,
      );

      expect(result).toBeDefined();
      expect(attemptCount).toBe(2);
    });
  });

  describe('getJobStatus', () => {
    it('should return processing job status', async () => {
      const options = {
        quality: '720p' as const,
        format: 'mp4' as const,
      };

      jest.spyOn(fs.promises, 'access').mockResolvedValue(undefined);
      jest.spyOn(fs.promises, 'stat').mockResolvedValue({ size: 1024 * 1024 * 50 } as any);
      jest.spyOn(videoProcessingService as any, 'validateVideo').mockResolvedValue(undefined);
      jest.spyOn(videoProcessingService as any, 'transcodeVideo').mockImplementation(async () => {
        // Simulate long-running process
        await new Promise(resolve => setTimeout(resolve, 100));
        return mockOutputPath;
      });

      // Start processing without awaiting
      const processingPromise = videoProcessingService.processVideo(
        'user_123',
        'recording_456',
        mockInputPath,
        options,
      );

      // Get job status
      const jobs = (videoProcessingService as any).activeJobs;
      const jobId = Array.from(jobs.keys())[0];

      if (jobId) {
        const status = videoProcessingService.getJobStatus(jobId);
        expect(status).toBeDefined();
        expect(status?.status).toBe('processing');
      }

      await processingPromise.catch(() => {}); // Cleanup
    });

    it('should return null for non-existent job', () => {
      const status = videoProcessingService.getJobStatus('non_existent_job');
      expect(status).toBeNull();
    });
  });

  describe('cancelJob', () => {
    it('should cancel running job', async () => {
      const options = {
        quality: '720p' as const,
        format: 'mp4' as const,
      };

      jest.spyOn(fs.promises, 'access').mockResolvedValue(undefined);
      jest.spyOn(fs.promises, 'stat').mockResolvedValue({ size: 1024 * 1024 * 50 } as any);
      jest.spyOn(videoProcessingService as any, 'validateVideo').mockResolvedValue(undefined);
      jest.spyOn(videoProcessingService as any, 'transcodeVideo').mockImplementation(async () => {
        await new Promise(resolve => setTimeout(resolve, 1000));
        return mockOutputPath;
      });

      // Start processing
      const processingPromise = videoProcessingService.processVideo(
        'user_123',
        'recording_456',
        mockInputPath,
        options,
      );

      // Cancel job
      const jobs = (videoProcessingService as any).activeJobs;
      const jobId = Array.from(jobs.keys())[0];

      if (jobId) {
        const cancelled = await videoProcessingService.cancelJob(jobId);
        expect(cancelled).toBe(true);
      }

      await processingPromise.catch(() => {}); // Cleanup
    });
  });
});
