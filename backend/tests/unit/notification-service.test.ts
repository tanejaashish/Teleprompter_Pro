// Comprehensive Test Suite - Notification Service
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { NotificationService } from '../../notification-service/src/notification-service';

jest.mock('@prisma/client');
jest.mock('nodemailer');
jest.mock('@sendgrid/mail');
jest.mock('firebase-admin');

describe('NotificationService', () => {
  let notificationService: NotificationService;
  let mockPrisma: any;
  let mockSendGrid: any;
  let mockFirebase: any;

  beforeEach(() => {
    notificationService = new NotificationService();
    mockPrisma = {
      notification: {
        create: jest.fn(),
        findMany: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
        count: jest.fn(),
      },
      user: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
      },
    };

    mockSendGrid = {
      send: jest.fn().mockResolvedValue([{ statusCode: 202 }]),
    };

    mockFirebase = {
      messaging: jest.fn().mockReturnValue({
        send: jest.fn().mockResolvedValue('message_id_123'),
        sendMulticast: jest.fn().mockResolvedValue({
          successCount: 1,
          failureCount: 0,
        }),
      }),
    };
  });

  describe('sendNotification', () => {
    it('should send email notification', async () => {
      const notification = {
        userId: 'user_123',
        type: 'welcome' as const,
        title: 'Welcome!',
        message: 'Welcome to TelePrompt Pro',
        channel: 'email' as const,
      };

      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'user_123',
        email: 'test@example.com',
        displayName: 'Test User',
      });

      mockPrisma.notification.create.mockResolvedValue({
        id: 'notif_123',
        ...notification,
      });

      (notificationService as any).sendgridClient = mockSendGrid;

      await notificationService.sendNotification(notification);

      expect(mockSendGrid.send).toHaveBeenCalled();
      expect(mockPrisma.notification.create).toHaveBeenCalled();
    });

    it('should send push notification', async () => {
      const notification = {
        userId: 'user_123',
        type: 'recording_complete' as const,
        title: 'Recording Ready',
        message: 'Your recording is ready to view',
        channel: 'push' as const,
      };

      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'user_123',
        email: 'test@example.com',
        fcmToken: 'fcm_token_123',
      });

      mockPrisma.notification.create.mockResolvedValue({
        id: 'notif_123',
        ...notification,
      });

      (notificationService as any).firebaseAdmin = mockFirebase;

      await notificationService.sendNotification(notification);

      const messaging = mockFirebase.messaging();
      expect(messaging.send).toHaveBeenCalled();
      expect(mockPrisma.notification.create).toHaveBeenCalled();
    });

    it('should create in-app notification', async () => {
      const notification = {
        userId: 'user_123',
        type: 'script_shared' as const,
        title: 'New Shared Script',
        message: 'Someone shared a script with you',
        channel: 'in_app' as const,
      };

      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'user_123',
        email: 'test@example.com',
      });

      mockPrisma.notification.create.mockResolvedValue({
        id: 'notif_123',
        ...notification,
      });

      await notificationService.sendNotification(notification);

      expect(mockPrisma.notification.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          userId: 'user_123',
          type: 'script_shared',
          channel: 'in_app',
        }),
      });
    });

    it('should throw error if user not found', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);

      await expect(
        notificationService.sendNotification({
          userId: 'invalid_user',
          type: 'welcome',
          title: 'Test',
          message: 'Test',
          channel: 'email',
        }),
      ).rejects.toThrow('User not found');
    });

    it('should emit notification_sent event', async (done) => {
      const notification = {
        userId: 'user_123',
        type: 'welcome' as const,
        title: 'Welcome',
        message: 'Welcome message',
        channel: 'email' as const,
      };

      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'user_123',
        email: 'test@example.com',
      });

      mockPrisma.notification.create.mockResolvedValue({ id: 'notif_123' });

      (notificationService as any).sendgridClient = mockSendGrid;

      notificationService.on('notification_sent', (data) => {
        expect(data.userId).toBe('user_123');
        expect(data.type).toBe('welcome');
        done();
      });

      await notificationService.sendNotification(notification);
    });
  });

  describe('getEmailTemplate', () => {
    it('should return welcome email template', () => {
      const template = (notificationService as any).getEmailTemplate('welcome', {
        userName: 'John Doe',
      });

      expect(template).toBeDefined();
      expect(template.subject).toContain('Welcome');
      expect(template.html).toContain('John Doe');
    });

    it('should return subscription activated template', () => {
      const template = (notificationService as any).getEmailTemplate('subscription_activated', {
        plan: 'Pro',
      });

      expect(template).toBeDefined();
      expect(template.subject).toContain('Pro');
      expect(template.html).toContain('Pro');
    });

    it('should return trial ending template', () => {
      const template = (notificationService as any).getEmailTemplate('trial_ending', {
        daysLeft: 3,
      });

      expect(template).toBeDefined();
      expect(template.subject).toContain('Trial');
      expect(template.html).toContain('3');
    });

    it('should return default template for unknown type', () => {
      const template = (notificationService as any).getEmailTemplate('unknown_type');

      expect(template).toBeDefined();
      expect(template.subject).toBe('Notification from TelePrompt Pro');
    });
  });

  describe('sendEmail', () => {
    it('should send email via SendGrid', async () => {
      const user = {
        email: 'test@example.com',
        displayName: 'Test User',
      };

      const notification = {
        type: 'welcome',
        title: 'Welcome',
        message: 'Welcome message',
        data: { userName: 'Test User' },
      };

      (notificationService as any).sendgridClient = mockSendGrid;

      await (notificationService as any).sendEmail(user.email, notification);

      expect(mockSendGrid.send).toHaveBeenCalledWith(
        expect.objectContaining({
          to: 'test@example.com',
          from: process.env.SMTP_FROM_EMAIL,
          subject: expect.any(String),
          html: expect.any(String),
        }),
      );
    });

    it('should fallback to SMTP if SendGrid fails', async () => {
      const user = { email: 'test@example.com' };
      const notification = {
        type: 'welcome',
        title: 'Welcome',
        message: 'Welcome',
      };

      mockSendGrid.send.mockRejectedValue(new Error('SendGrid error'));

      const mockTransporter = {
        sendMail: jest.fn().mockResolvedValue({ messageId: 'msg_123' }),
      };

      (notificationService as any).sendgridClient = mockSendGrid;
      (notificationService as any).smtpTransporter = mockTransporter;

      await (notificationService as any).sendEmail(user.email, notification);

      expect(mockTransporter.sendMail).toHaveBeenCalled();
    });

    it('should retry on transient failures', async () => {
      const user = { email: 'test@example.com' };
      const notification = {
        type: 'welcome',
        title: 'Welcome',
        message: 'Welcome',
      };

      let attemptCount = 0;
      mockSendGrid.send.mockImplementation(() => {
        attemptCount++;
        if (attemptCount < 2) {
          return Promise.reject(new Error('Network error'));
        }
        return Promise.resolve([{ statusCode: 202 }]);
      });

      (notificationService as any).sendgridClient = mockSendGrid;

      await (notificationService as any).sendEmail(user.email, notification);

      expect(attemptCount).toBe(2);
      expect(mockSendGrid.send).toHaveBeenCalledTimes(2);
    });
  });

  describe('sendPushNotification', () => {
    it('should send push notification via FCM', async () => {
      const user = {
        id: 'user_123',
        fcmToken: 'fcm_token_123',
      };

      const notification = {
        type: 'recording_complete',
        title: 'Recording Ready',
        message: 'Your recording is ready',
        data: { recordingId: 'rec_123' },
      };

      (notificationService as any).firebaseAdmin = mockFirebase;

      await (notificationService as any).sendPushNotification(user, notification);

      const messaging = mockFirebase.messaging();
      expect(messaging.send).toHaveBeenCalledWith(
        expect.objectContaining({
          token: 'fcm_token_123',
          notification: expect.objectContaining({
            title: 'Recording Ready',
            body: 'Your recording is ready',
          }),
        }),
      );
    });

    it('should handle invalid FCM token', async () => {
      const user = {
        id: 'user_123',
        fcmToken: 'invalid_token',
      };

      const notification = {
        type: 'test',
        title: 'Test',
        message: 'Test',
      };

      const mockMessaging = {
        send: jest.fn().mockRejectedValue({
          code: 'messaging/invalid-registration-token',
        }),
      };

      (notificationService as any).firebaseAdmin = {
        messaging: () => mockMessaging,
      };

      mockPrisma.user.update = jest.fn();

      await (notificationService as any).sendPushNotification(user, notification);

      // Should clear invalid token
      expect(mockPrisma.user.update).toHaveBeenCalledWith({
        where: { id: 'user_123' },
        data: { fcmToken: null },
      });
    });
  });

  describe('getUserNotifications', () => {
    it('should retrieve user notifications', async () => {
      const userId = 'user_123';

      mockPrisma.notification.findMany.mockResolvedValue([
        {
          id: 'notif_1',
          userId: 'user_123',
          type: 'welcome',
          title: 'Welcome',
          message: 'Welcome message',
          read: false,
          createdAt: new Date(),
        },
        {
          id: 'notif_2',
          userId: 'user_123',
          type: 'recording_complete',
          title: 'Recording Ready',
          message: 'Your recording is ready',
          read: true,
          createdAt: new Date(),
        },
      ]);

      const notifications = await notificationService.getUserNotifications(userId);

      expect(notifications).toHaveLength(2);
      expect(notifications[0].id).toBe('notif_1');
    });

    it('should filter unread notifications', async () => {
      const userId = 'user_123';

      mockPrisma.notification.findMany.mockResolvedValue([
        {
          id: 'notif_1',
          userId: 'user_123',
          type: 'welcome',
          read: false,
        },
      ]);

      const notifications = await notificationService.getUserNotifications(userId, {
        unreadOnly: true,
      });

      expect(mockPrisma.notification.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            read: false,
          }),
        }),
      );
    });

    it('should paginate notifications', async () => {
      const userId = 'user_123';

      mockPrisma.notification.findMany.mockResolvedValue([]);

      await notificationService.getUserNotifications(userId, {
        limit: 20,
        offset: 40,
      });

      expect(mockPrisma.notification.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          take: 20,
          skip: 40,
        }),
      );
    });
  });

  describe('markAsRead', () => {
    it('should mark single notification as read', async () => {
      mockPrisma.notification.update.mockResolvedValue({
        id: 'notif_123',
        read: true,
      });

      await notificationService.markAsRead('notif_123');

      expect(mockPrisma.notification.update).toHaveBeenCalledWith({
        where: { id: 'notif_123' },
        data: { read: true, readAt: expect.any(Date) },
      });
    });
  });

  describe('markAllAsRead', () => {
    it('should mark all user notifications as read', async () => {
      mockPrisma.notification.updateMany.mockResolvedValue({ count: 5 });

      await notificationService.markAllAsRead('user_123');

      expect(mockPrisma.notification.updateMany).toHaveBeenCalledWith({
        where: {
          userId: 'user_123',
          read: false,
        },
        data: {
          read: true,
          readAt: expect.any(Date),
        },
      });
    });
  });

  describe('getUnreadCount', () => {
    it('should return count of unread notifications', async () => {
      mockPrisma.notification.count.mockResolvedValue(7);

      const count = await notificationService.getUnreadCount('user_123');

      expect(count).toBe(7);
      expect(mockPrisma.notification.count).toHaveBeenCalledWith({
        where: {
          userId: 'user_123',
          read: false,
        },
      });
    });
  });

  describe('scheduleNotification', () => {
    it('should schedule notification for future delivery', async () => {
      const notification = {
        userId: 'user_123',
        type: 'trial_ending' as const,
        title: 'Trial Ending',
        message: 'Your trial ends in 3 days',
        channel: 'email' as const,
      };

      const scheduledTime = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000); // 3 days

      mockPrisma.notification.create.mockResolvedValue({
        id: 'notif_123',
        ...notification,
        scheduledFor: scheduledTime,
      });

      await notificationService.scheduleNotification(notification, scheduledTime);

      expect(mockPrisma.notification.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          userId: 'user_123',
          scheduledFor: scheduledTime,
        }),
      });
    });

    it('should process scheduled notifications', async () => {
      const now = new Date();

      mockPrisma.notification.findMany.mockResolvedValue([
        {
          id: 'notif_1',
          userId: 'user_123',
          type: 'trial_ending',
          title: 'Trial Ending',
          message: 'Trial ending soon',
          channel: 'email',
          scheduledFor: new Date(now.getTime() - 1000), // Past time
        },
      ]);

      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'user_123',
        email: 'test@example.com',
      });

      mockPrisma.notification.update.mockResolvedValue({});

      (notificationService as any).sendgridClient = mockSendGrid;

      await (notificationService as any).processScheduledNotifications();

      expect(mockSendGrid.send).toHaveBeenCalled();
      expect(mockPrisma.notification.update).toHaveBeenCalled();
    });
  });

  describe('sendBulkNotifications', () => {
    it('should send notifications to multiple users', async () => {
      const userIds = ['user_1', 'user_2', 'user_3'];
      const notification = {
        type: 'announcement' as const,
        title: 'New Feature',
        message: 'Check out our new feature!',
        channel: 'email' as const,
      };

      mockPrisma.user.findMany.mockResolvedValue([
        { id: 'user_1', email: 'user1@example.com', fcmToken: 'token_1' },
        { id: 'user_2', email: 'user2@example.com', fcmToken: 'token_2' },
        { id: 'user_3', email: 'user3@example.com', fcmToken: null },
      ]);

      mockPrisma.notification.create.mockResolvedValue({});

      (notificationService as any).sendgridClient = mockSendGrid;

      await notificationService.sendBulkNotifications(userIds, notification);

      expect(mockSendGrid.send).toHaveBeenCalledTimes(3);
      expect(mockPrisma.notification.create).toHaveBeenCalledTimes(3);
    });

    it('should handle partial failures gracefully', async () => {
      const userIds = ['user_1', 'user_2'];
      const notification = {
        type: 'announcement' as const,
        title: 'Test',
        message: 'Test message',
        channel: 'email' as const,
      };

      mockPrisma.user.findMany.mockResolvedValue([
        { id: 'user_1', email: 'user1@example.com' },
        { id: 'user_2', email: 'user2@example.com' },
      ]);

      mockSendGrid.send
        .mockResolvedValueOnce([{ statusCode: 202 }])
        .mockRejectedValueOnce(new Error('Send failed'));

      mockPrisma.notification.create.mockResolvedValue({});

      (notificationService as any).sendgridClient = mockSendGrid;

      const result = await notificationService.sendBulkNotifications(userIds, notification);

      expect(result.successCount).toBe(1);
      expect(result.failureCount).toBe(1);
    });
  });
});
