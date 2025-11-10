// Analytics Service
// Comprehensive analytics and reporting for user activity and system metrics

import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

export interface AnalyticsDashboard {
  usage: UsageStatistics;
  performance: PerformanceMetrics;
  content: ContentAnalytics;
  engagement: EngagementMetrics;
}

export interface UsageStatistics {
  totalSessions: number;
  averageSessionDuration: number;
  scriptsCreated: number;
  scriptsEdited: number;
  recordingsCompleted: number;
  totalRecordingTime: number;
  storageUsed: number;
  aiWordsGenerated: number;
}

export interface PerformanceMetrics {
  averageLoadTime: number;
  errorRate: number;
  apiResponseTime: number;
  videoProcessingTime: number;
}

export interface ContentAnalytics {
  mostUsedCategories: Array<{ category: string; count: number }>;
  averageScriptLength: number;
  totalWords: number;
  popularTags: Array<{ tag: string; count: number }>;
}

export interface EngagementMetrics {
  dailyActiveUsers: number;
  weeklyActiveUsers: number;
  monthlyActiveUsers: number;
  retentionRate: number;
  churnRate: number;
}

export class AnalyticsService {
  // Get comprehensive dashboard for user
  async getUserDashboard(
    userId: string,
    dateRange: { start: Date; end: Date },
  ): Promise<AnalyticsDashboard> {
    const [usage, performance, content, engagement] =
      await Promise.all([
        this.getUsageStatistics(userId, dateRange),
        this.getPerformanceMetrics(userId, dateRange),
        this.getContentAnalytics(userId, dateRange),
        this.getEngagementMetrics(userId, dateRange),
      ]);

    return {
      usage,
      performance,
      content,
      engagement,
    };
  }

  // Get usage statistics
  private async getUsageStatistics(
    userId: string,
    dateRange: { start: Date; end: Date },
  ): Promise<UsageStatistics> {
    const [
      sessions,
      scripts,
      recordings,
      usageRecords,
    ] = await Promise.all([
      prisma.session.findMany({
        where: {
          userId,
          createdAt: {
            gte: dateRange.start,
            lte: dateRange.end,
          },
        },
      }),
      prisma.script.findMany({
        where: {
          userId,
          createdAt: {
            gte: dateRange.start,
            lte: dateRange.end,
          },
        },
      }),
      prisma.recording.findMany({
        where: {
          userId,
          createdAt: {
            gte: dateRange.start,
            lte: dateRange.end,
          },
        },
      }),
      prisma.usageRecord.findMany({
        where: {
          userId,
          recordedAt: {
            gte: dateRange.start,
            lte: dateRange.end,
          },
        },
      }),
    ]);

    const totalRecordingTime = recordings.reduce(
      (sum, r) => sum + r.duration,
      0,
    );
    const totalFileSize = recordings.reduce(
      (sum, r) => sum + Number(r.fileSize),
      0,
    );
    const aiWords = usageRecords
      .filter((r) => r.resourceType === "ai_generation")
      .reduce((sum, r) => sum + r.quantity, 0);

    // Calculate average session duration
    const sessionDurations = sessions.map(
      (s) => s.expiresAt.getTime() - s.createdAt.getTime(),
    );
    const avgDuration =
      sessionDurations.length > 0
        ? sessionDurations.reduce((a, b) => a + b, 0) /
          sessionDurations.length
        : 0;

    return {
      totalSessions: sessions.length,
      averageSessionDuration: avgDuration / 1000 / 60, // in minutes
      scriptsCreated: scripts.length,
      scriptsEdited: scripts.filter(
        (s) =>
          s.updatedAt.getTime() !== s.createdAt.getTime(),
      ).length,
      recordingsCompleted: recordings.filter(
        (r) => r.status === "completed",
      ).length,
      totalRecordingTime, // in seconds
      storageUsed: totalFileSize,
      aiWordsGenerated: aiWords,
    };
  }

  // Get performance metrics
  private async getPerformanceMetrics(
    userId: string,
    dateRange: { start: Date; end: Date },
  ): Promise<PerformanceMetrics> {
    // Query activity logs for performance data
    const activities = await prisma.activity.findMany({
      where: {
        userId,
        createdAt: {
          gte: dateRange.start,
          lte: dateRange.end,
        },
      },
    });

    // Calculate metrics from metadata
    const loadTimes: number[] = [];
    let errorCount = 0;

    activities.forEach((activity) => {
      const metadata = activity.metadata as any;
      if (metadata?.loadTime) {
        loadTimes.push(metadata.loadTime);
      }
      if (activity.type.includes("error")) {
        errorCount++;
      }
    });

    const avgLoadTime =
      loadTimes.length > 0
        ? loadTimes.reduce((a, b) => a + b, 0) / loadTimes.length
        : 0;

    return {
      averageLoadTime: avgLoadTime,
      errorRate:
        activities.length > 0
          ? (errorCount / activities.length) * 100
          : 0,
      apiResponseTime: avgLoadTime, // Simplified
      videoProcessingTime: 0, // TODO: Track from recordings
    };
  }

  // Get content analytics
  private async getContentAnalytics(
    userId: string,
    dateRange: { start: Date; end: Date },
  ): Promise<ContentAnalytics> {
    const scripts = await prisma.script.findMany({
      where: {
        userId,
        createdAt: {
          gte: dateRange.start,
          lte: dateRange.end,
        },
        deletedAt: null,
      },
    });

    // Category counts
    const categoryMap = new Map<string, number>();
    scripts.forEach((script) => {
      if (script.category) {
        categoryMap.set(
          script.category,
          (categoryMap.get(script.category) || 0) + 1,
        );
      }
    });

    const mostUsedCategories = Array.from(categoryMap.entries())
      .map(([category, count]) => ({ category, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10);

    // Tag counts
    const tagMap = new Map<string, number>();
    scripts.forEach((script) => {
      script.tags.forEach((tag) => {
        tagMap.set(tag, (tagMap.get(tag) || 0) + 1);
      });
    });

    const popularTags = Array.from(tagMap.entries())
      .map(([tag, count]) => ({ tag, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10);

    const totalWords = scripts.reduce(
      (sum, s) => sum + s.wordCount,
      0,
    );
    const avgLength =
      scripts.length > 0 ? totalWords / scripts.length : 0;

    return {
      mostUsedCategories,
      averageScriptLength: avgLength,
      totalWords,
      popularTags,
    };
  }

  // Get engagement metrics
  private async getEngagementMetrics(
    userId: string,
    dateRange: { start: Date; end: Date },
  ): Promise<EngagementMetrics> {
    const now = new Date();
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const oneWeekAgo = new Date(
      now.getTime() - 7 * 24 * 60 * 60 * 1000,
    );
    const oneMonthAgo = new Date(
      now.getTime() - 30 * 24 * 60 * 60 * 1000,
    );

    const [dailyActivity, weeklyActivity, monthlyActivity] =
      await Promise.all([
        prisma.activity.count({
          where: { userId, createdAt: { gte: oneDayAgo } },
        }),
        prisma.activity.count({
          where: { userId, createdAt: { gte: oneWeekAgo } },
        }),
        prisma.activity.count({
          where: { userId, createdAt: { gte: oneMonthAgo } },
        }),
      ]);

    return {
      dailyActiveUsers: dailyActivity > 0 ? 1 : 0,
      weeklyActiveUsers: weeklyActivity > 0 ? 1 : 0,
      monthlyActiveUsers: monthlyActivity > 0 ? 1 : 0,
      retentionRate: 0, // TODO: Calculate based on cohort analysis
      churnRate: 0, // TODO: Calculate based on subscription data
    };
  }

  // Generate custom report
  async generateReport(
    userId: string,
    reportType: string,
    params: any,
  ): Promise<any> {
    switch (reportType) {
      case "script_performance":
        return await this.generateScriptPerformanceReport(
          userId,
          params,
        );

      case "recording_analytics":
        return await this.generateRecordingAnalyticsReport(
          userId,
          params,
        );

      case "usage_summary":
        return await this.generateUsageSummaryReport(
          userId,
          params,
        );

      default:
        throw new Error("Unknown report type");
    }
  }

  // Script performance report
  private async generateScriptPerformanceReport(
    userId: string,
    params: any,
  ): Promise<any> {
    const scripts = await prisma.script.findMany({
      where: { userId, deletedAt: null },
      include: { recordings: true },
    });

    return scripts.map((script) => ({
      id: script.id,
      title: script.title,
      wordCount: script.wordCount,
      createdAt: script.createdAt,
      timesRecorded: script.recordings.length,
      lastUsed: script.lastOpenedAt,
      category: script.category,
      tags: script.tags,
    }));
  }

  // Recording analytics report
  private async generateRecordingAnalyticsReport(
    userId: string,
    params: any,
  ): Promise<any> {
    const recordings = await prisma.recording.findMany({
      where: { userId, deletedAt: null },
      include: { script: true },
    });

    const totalDuration = recordings.reduce(
      (sum, r) => sum + r.duration,
      0,
    );
    const totalSize = recordings.reduce(
      (sum, r) => sum + Number(r.fileSize),
      0,
    );

    return {
      totalRecordings: recordings.length,
      totalDuration,
      totalSize,
      averageDuration: totalDuration / recordings.length || 0,
      byQuality: this.groupBy(recordings, "quality"),
      byFormat: this.groupBy(recordings, "format"),
      byMonth: this.groupByMonth(recordings),
    };
  }

  // Usage summary report
  private async generateUsageSummaryReport(
    userId: string,
    params: any,
  ): Promise<any> {
    const dateRange = {
      start: params.startDate || new Date(0),
      end: params.endDate || new Date(),
    };

    return await this.getUserDashboard(userId, dateRange);
  }

  // Helper: Group by field
  private groupBy(items: any[], field: string): Record<string, number> {
    const grouped: Record<string, number> = {};
    items.forEach((item) => {
      const value = item[field] || "unknown";
      grouped[value] = (grouped[value] || 0) + 1;
    });
    return grouped;
  }

  // Helper: Group by month
  private groupByMonth(items: any[]): Record<string, number> {
    const grouped: Record<string, number> = {};
    items.forEach((item) => {
      const month = item.createdAt.toISOString().slice(0, 7);
      grouped[month] = (grouped[month] || 0) + 1;
    });
    return grouped;
  }

  // Track custom event
  async trackEvent(
    userId: string,
    eventType: string,
    metadata: any,
  ): Promise<void> {
    await prisma.activity.create({
      data: {
        userId,
        type: eventType,
        action: "create",
        metadata,
      },
    });
  }

  // Real-time metrics (cached)
  async getRealtimeMetrics(userId: string): Promise<any> {
    // Get recent activity (last 24 hours)
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const [recentActivities, activeSessions] = await Promise.all([
      prisma.activity.findMany({
        where: {
          userId,
          createdAt: { gte: oneDayAgo },
        },
        orderBy: { createdAt: "desc" },
        take: 10,
      }),
      prisma.session.findMany({
        where: {
          userId,
          expiresAt: { gte: new Date() },
        },
      }),
    ]);

    return {
      recentActivity: recentActivities,
      activeSessions: activeSessions.length,
      lastActive: recentActivities[0]?.createdAt || null,
    };
  }
}

export const analyticsService = new AnalyticsService();
