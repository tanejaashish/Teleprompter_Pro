// Comprehensive Test Suite - Analytics Service
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { AnalyticsService } from '../../analytics-service/src/analytics-service';

jest.mock('@prisma/client');

describe('AnalyticsService', () => {
  let analyticsService: AnalyticsService;
  let mockPrisma: any;

  beforeEach(() => {
    analyticsService = new AnalyticsService();
    mockPrisma = {
      script: {
        findMany: jest.fn(),
        count: jest.fn(),
      },
      recording: {
        findMany: jest.fn(),
        count: jest.fn(),
      },
      usageRecord: {
        findMany: jest.fn(),
        groupBy: jest.fn(),
      },
      activity: {
        findMany: jest.fn(),
        create: jest.fn(),
      },
    };
  });

  describe('getUserDashboard', () => {
    it('should return comprehensive dashboard data', async () => {
      const userId = 'user_123';
      const dateRange = {
        start: new Date('2024-01-01'),
        end: new Date('2024-01-31'),
      };

      mockPrisma.script.count.mockResolvedValue(10);
      mockPrisma.recording.count.mockResolvedValue(25);
      mockPrisma.usageRecord.findMany.mockResolvedValue([
        { resourceType: 'ai_generation', quantity: 1000 },
        { resourceType: 'storage', quantity: 500000000 },
      ]);
      mockPrisma.recording.findMany.mockResolvedValue([
        { duration: 300, createdAt: new Date('2024-01-15') },
        { duration: 450, createdAt: new Date('2024-01-20') },
      ]);

      const dashboard = await analyticsService.getUserDashboard(userId, dateRange);

      expect(dashboard).toBeDefined();
      expect(dashboard.usage).toBeDefined();
      expect(dashboard.performance).toBeDefined();
      expect(dashboard.content).toBeDefined();
      expect(dashboard.engagement).toBeDefined();
    });

    it('should handle users with no activity', async () => {
      const userId = 'user_new';
      const dateRange = {
        start: new Date('2024-01-01'),
        end: new Date('2024-01-31'),
      };

      mockPrisma.script.count.mockResolvedValue(0);
      mockPrisma.recording.count.mockResolvedValue(0);
      mockPrisma.usageRecord.findMany.mockResolvedValue([]);
      mockPrisma.recording.findMany.mockResolvedValue([]);

      const dashboard = await analyticsService.getUserDashboard(userId, dateRange);

      expect(dashboard).toBeDefined();
      expect(dashboard.usage.totalScripts).toBe(0);
      expect(dashboard.usage.totalRecordings).toBe(0);
    });
  });

  describe('getUsageStatistics', () => {
    it('should calculate usage statistics correctly', async () => {
      const userId = 'user_123';
      const dateRange = {
        start: new Date('2024-01-01'),
        end: new Date('2024-01-31'),
      };

      mockPrisma.script.count.mockResolvedValue(15);
      mockPrisma.recording.count.mockResolvedValue(30);
      mockPrisma.usageRecord.findMany.mockResolvedValue([
        { resourceType: 'ai_generation', quantity: 5000, unit: 'words' },
        { resourceType: 'storage', quantity: 1024 * 1024 * 1024, unit: 'bytes' },
        { resourceType: 'transcription', quantity: 60, unit: 'minutes' },
      ]);

      const usage = await analyticsService.getUsageStatistics(userId, dateRange);

      expect(usage.totalScripts).toBe(15);
      expect(usage.totalRecordings).toBe(30);
      expect(usage.aiWordsGenerated).toBe(5000);
      expect(usage.storageUsed).toBe(1024 * 1024 * 1024);
      expect(usage.transcriptionMinutes).toBe(60);
    });

    it('should track usage trends over time', async () => {
      const userId = 'user_123';
      const dateRange = {
        start: new Date('2024-01-01'),
        end: new Date('2024-01-31'),
      };

      mockPrisma.script.count.mockResolvedValue(20);
      mockPrisma.recording.count.mockResolvedValue(40);
      mockPrisma.usageRecord.findMany.mockResolvedValue([
        {
          resourceType: 'ai_generation',
          quantity: 3000,
          createdAt: new Date('2024-01-15'),
        },
        {
          resourceType: 'ai_generation',
          quantity: 4000,
          createdAt: new Date('2024-01-25'),
        },
      ]);

      const usage = await analyticsService.getUsageStatistics(userId, dateRange);

      expect(usage).toBeDefined();
      expect(usage.trends).toBeDefined();
    });
  });

  describe('getPerformanceMetrics', () => {
    it('should calculate average recording duration', async () => {
      const userId = 'user_123';
      const dateRange = {
        start: new Date('2024-01-01'),
        end: new Date('2024-01-31'),
      };

      mockPrisma.recording.findMany.mockResolvedValue([
        { duration: 300 },
        { duration: 450 },
        { duration: 600 },
      ]);

      const performance = await analyticsService.getPerformanceMetrics(userId, dateRange);

      expect(performance.avgRecordingDuration).toBe(450);
      expect(performance.totalRecordingTime).toBe(1350);
    });

    it('should track recordings per day', async () => {
      const userId = 'user_123';
      const dateRange = {
        start: new Date('2024-01-01'),
        end: new Date('2024-01-31'),
      };

      mockPrisma.recording.findMany.mockResolvedValue([
        { createdAt: new Date('2024-01-15'), duration: 300 },
        { createdAt: new Date('2024-01-15'), duration: 400 },
        { createdAt: new Date('2024-01-20'), duration: 500 },
      ]);

      const performance = await analyticsService.getPerformanceMetrics(userId, dateRange);

      expect(performance).toBeDefined();
      expect(performance.recordingsPerDay).toBeDefined();
    });
  });

  describe('getContentAnalytics', () => {
    it('should analyze script categories', async () => {
      const userId = 'user_123';
      const dateRange = {
        start: new Date('2024-01-01'),
        end: new Date('2024-01-31'),
      };

      mockPrisma.script.findMany.mockResolvedValue([
        { category: 'presentation', wordCount: 500 },
        { category: 'presentation', wordCount: 700 },
        { category: 'video', wordCount: 1000 },
        { category: 'speech', wordCount: 800 },
      ]);

      const content = await analyticsService.getContentAnalytics(userId, dateRange);

      expect(content.categoryBreakdown).toBeDefined();
      expect(content.categoryBreakdown['presentation']).toBe(2);
      expect(content.categoryBreakdown['video']).toBe(1);
      expect(content.totalWordCount).toBe(3000);
    });

    it('should track most used tags', async () => {
      const userId = 'user_123';
      const dateRange = {
        start: new Date('2024-01-01'),
        end: new Date('2024-01-31'),
      };

      mockPrisma.script.findMany.mockResolvedValue([
        { tags: ['business', 'meeting'], wordCount: 500 },
        { tags: ['business', 'presentation'], wordCount: 700 },
        { tags: ['tutorial', 'tech'], wordCount: 600 },
      ]);

      const content = await analyticsService.getContentAnalytics(userId, dateRange);

      expect(content.topTags).toBeDefined();
      expect(content.topTags[0].tag).toBe('business');
      expect(content.topTags[0].count).toBe(2);
    });
  });

  describe('getEngagementMetrics', () => {
    it('should calculate daily active days', async () => {
      const userId = 'user_123';
      const dateRange = {
        start: new Date('2024-01-01'),
        end: new Date('2024-01-31'),
      };

      mockPrisma.activity.findMany.mockResolvedValue([
        { type: 'script_created', createdAt: new Date('2024-01-05') },
        { type: 'recording_created', createdAt: new Date('2024-01-05') },
        { type: 'script_edited', createdAt: new Date('2024-01-10') },
        { type: 'recording_created', createdAt: new Date('2024-01-15') },
      ]);

      const engagement = await analyticsService.getEngagementMetrics(userId, dateRange);

      expect(engagement.activeDays).toBe(3); // 3 unique days
      expect(engagement.totalActions).toBe(4);
    });

    it('should track feature usage', async () => {
      const userId = 'user_123';
      const dateRange = {
        start: new Date('2024-01-01'),
        end: new Date('2024-01-31'),
      };

      mockPrisma.activity.findMany.mockResolvedValue([
        { type: 'ai_generation', metadata: { feature: 'script_generation' } },
        { type: 'ai_generation', metadata: { feature: 'script_generation' } },
        { type: 'voice_scrolling', metadata: { feature: 'voice_scrolling' } },
        { type: 'collaboration', metadata: { feature: 'real_time_edit' } },
      ]);

      const engagement = await analyticsService.getEngagementMetrics(userId, dateRange);

      expect(engagement.featureUsage).toBeDefined();
      expect(engagement.featureUsage['ai_generation']).toBe(2);
      expect(engagement.featureUsage['voice_scrolling']).toBe(1);
    });
  });

  describe('trackEvent', () => {
    it('should track user event', async () => {
      mockPrisma.activity.create.mockResolvedValue({
        id: 'activity_123',
        userId: 'user_123',
        type: 'script_created',
      });

      await analyticsService.trackEvent('user_123', 'script_created', {
        scriptId: 'script_456',
        title: 'New Script',
      });

      expect(mockPrisma.activity.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          userId: 'user_123',
          type: 'script_created',
          metadata: expect.any(Object),
        }),
      });
    });

    it('should emit event_tracked event', async (done) => {
      mockPrisma.activity.create.mockResolvedValue({
        id: 'activity_123',
      });

      analyticsService.on('event_tracked', (data) => {
        expect(data.userId).toBe('user_123');
        expect(data.eventType).toBe('recording_created');
        done();
      });

      await analyticsService.trackEvent('user_123', 'recording_created', {});
    });
  });

  describe('generateReport', () => {
    it('should generate script performance report', async () => {
      const userId = 'user_123';
      const params = {
        dateRange: {
          start: new Date('2024-01-01'),
          end: new Date('2024-01-31'),
        },
      };

      mockPrisma.script.findMany.mockResolvedValue([
        {
          id: 'script_1',
          title: 'Script 1',
          wordCount: 500,
          createdAt: new Date('2024-01-05'),
          recordings: [{ id: 'rec_1' }, { id: 'rec_2' }],
        },
        {
          id: 'script_2',
          title: 'Script 2',
          wordCount: 800,
          createdAt: new Date('2024-01-15'),
          recordings: [{ id: 'rec_3' }],
        },
      ]);

      const report = await analyticsService.generateReport(
        userId,
        'script_performance',
        params,
      );

      expect(report).toBeDefined();
      expect(report.scripts).toBeDefined();
      expect(report.scripts).toHaveLength(2);
      expect(report.scripts[0].recordingCount).toBe(2);
    });

    it('should generate recording analytics report', async () => {
      const userId = 'user_123';
      const params = {
        dateRange: {
          start: new Date('2024-01-01'),
          end: new Date('2024-01-31'),
        },
      };

      mockPrisma.recording.findMany.mockResolvedValue([
        {
          id: 'rec_1',
          title: 'Recording 1',
          duration: 300,
          fileSize: 1024 * 1024 * 50,
          createdAt: new Date('2024-01-10'),
        },
        {
          id: 'rec_2',
          title: 'Recording 2',
          duration: 450,
          fileSize: 1024 * 1024 * 75,
          createdAt: new Date('2024-01-20'),
        },
      ]);

      const report = await analyticsService.generateReport(
        userId,
        'recording_analytics',
        params,
      );

      expect(report).toBeDefined();
      expect(report.recordings).toBeDefined();
      expect(report.totalDuration).toBe(750);
      expect(report.avgDuration).toBe(375);
    });

    it('should generate usage summary report', async () => {
      const userId = 'user_123';
      const params = {
        dateRange: {
          start: new Date('2024-01-01'),
          end: new Date('2024-01-31'),
        },
      };

      mockPrisma.usageRecord.groupBy.mockResolvedValue([
        {
          resourceType: 'ai_generation',
          _sum: { quantity: 5000 },
        },
        {
          resourceType: 'storage',
          _sum: { quantity: 1024 * 1024 * 1024 },
        },
      ]);

      const report = await analyticsService.generateReport(
        userId,
        'usage_summary',
        params,
      );

      expect(report).toBeDefined();
      expect(report.usageByType).toBeDefined();
      expect(report.usageByType['ai_generation']).toBe(5000);
    });

    it('should throw error for invalid report type', async () => {
      await expect(
        analyticsService.generateReport('user_123', 'invalid_report', {}),
      ).rejects.toThrow('Invalid report type');
    });
  });

  describe('getComparisonData', () => {
    it('should compare current period with previous period', async () => {
      const userId = 'user_123';
      const currentPeriod = {
        start: new Date('2024-02-01'),
        end: new Date('2024-02-29'),
      };

      mockPrisma.script.count
        .mockResolvedValueOnce(20) // Current period
        .mockResolvedValueOnce(15); // Previous period

      mockPrisma.recording.count
        .mockResolvedValueOnce(40) // Current period
        .mockResolvedValueOnce(30); // Previous period

      const comparison = await analyticsService.getComparisonData(userId, currentPeriod);

      expect(comparison).toBeDefined();
      expect(comparison.scriptsGrowth).toBeCloseTo(33.33, 1); // 33.33% growth
      expect(comparison.recordingsGrowth).toBeCloseTo(33.33, 1); // 33.33% growth
    });
  });

  describe('exportAnalytics', () => {
    it('should export analytics data in CSV format', async () => {
      const userId = 'user_123';
      const dateRange = {
        start: new Date('2024-01-01'),
        end: new Date('2024-01-31'),
      };

      mockPrisma.script.findMany.mockResolvedValue([
        {
          id: 'script_1',
          title: 'Script 1',
          wordCount: 500,
          createdAt: new Date('2024-01-05'),
        },
      ]);

      const csv = await analyticsService.exportAnalytics(userId, dateRange, 'csv');

      expect(csv).toBeDefined();
      expect(typeof csv).toBe('string');
      expect(csv).toContain('script_1');
    });

    it('should export analytics data in JSON format', async () => {
      const userId = 'user_123';
      const dateRange = {
        start: new Date('2024-01-01'),
        end: new Date('2024-01-31'),
      };

      mockPrisma.script.findMany.mockResolvedValue([
        {
          id: 'script_1',
          title: 'Script 1',
          wordCount: 500,
        },
      ]);

      const json = await analyticsService.exportAnalytics(userId, dateRange, 'json');

      expect(json).toBeDefined();
      expect(typeof json).toBe('string');
      const parsed = JSON.parse(json);
      expect(parsed.scripts).toBeDefined();
    });
  });
});
