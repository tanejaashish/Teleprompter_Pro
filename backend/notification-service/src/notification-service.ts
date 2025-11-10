// Notification Service
// Multi-channel notification system (Email, Push, In-App)

import { PrismaClient } from "@prisma/client";
import nodemailer from "nodemailer";
import { EventEmitter } from "events";

const prisma = new PrismaClient();

export interface Notification {
  id: string;
  userId: string;
  type: string;
  title: string;
  message: string;
  channel: "email" | "push" | "in_app";
  priority: "low" | "medium" | "high" | "urgent";
  data?: Record<string, any>;
  read: boolean;
  createdAt: Date;
}

export interface EmailTemplate {
  subject: string;
  text: string;
  html: string;
}

export class NotificationService extends EventEmitter {
  private emailTransporter: nodemailer.Transporter;

  constructor() {
    super();
    this.initializeEmailTransporter();
  }

  // Initialize email transporter
  private initializeEmailTransporter(): void {
    if (process.env.SENDGRID_API_KEY) {
      // SendGrid configuration
      this.emailTransporter = nodemailer.createTransport({
        host: "smtp.sendgrid.net",
        port: 587,
        auth: {
          user: "apikey",
          pass: process.env.SENDGRID_API_KEY,
        },
      });
    } else {
      // Fallback to SMTP
      this.emailTransporter = nodemailer.createTransporter({
        host: process.env.SMTP_HOST || "smtp.gmail.com",
        port: parseInt(process.env.SMTP_PORT || "587"),
        secure: process.env.SMTP_SECURE === "true",
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASSWORD,
        },
      });
    }
  }

  // Send notification
  async sendNotification(notification: Omit<Notification, "id" | "read" | "createdAt">): Promise<void> {
    const user = await prisma.user.findUnique({
      where: { id: notification.userId },
    });

    if (!user) {
      throw new Error("User not found");
    }

    // Route to appropriate channel
    switch (notification.channel) {
      case "email":
        await this.sendEmail(user.email, notification);
        break;

      case "push":
        await this.sendPushNotification(user, notification);
        break;

      case "in_app":
        await this.createInAppNotification(notification);
        break;
    }

    // Emit event for real-time updates
    this.emit("notification_sent", {
      userId: notification.userId,
      type: notification.type,
      channel: notification.channel,
    });
  }

  // Send email notification
  private async sendEmail(
    to: string,
    notification: Omit<Notification, "id" | "read" | "createdAt">,
  ): Promise<void> {
    const template = this.getEmailTemplate(notification.type, notification.data);

    try {
      await this.emailTransporter.sendMail({
        from: `${process.env.SENDGRID_FROM_NAME || "TelePrompt Pro"} <${process.env.SENDGRID_FROM_EMAIL || "noreply@teleprompt.pro"}>`,
        to,
        subject: template.subject,
        text: template.text,
        html: template.html,
      });

      console.log(`Email sent to ${to}: ${notification.type}`);
    } catch (error) {
      console.error("Email sending failed:", error);
      throw error;
    }
  }

  // Send push notification
  private async sendPushNotification(
    user: any,
    notification: Omit<Notification, "id" | "read" | "createdAt">,
  ): Promise<void> {
    // TODO: Integrate with FCM (Firebase Cloud Messaging)
    // For now, log the notification

    console.log(`Push notification for user ${user.id}: ${notification.title}`);

    // FCM implementation would go here
    // const message = {
    //   notification: {
    //     title: notification.title,
    //     body: notification.message,
    //   },
    //   data: notification.data || {},
    //   token: user.fcmToken,
    // };
    //
    // await admin.messaging().send(message);
  }

  // Create in-app notification
  private async createInAppNotification(
    notification: Omit<Notification, "id" | "read" | "createdAt">,
  ): Promise<void> {
    // Store in database for in-app display
    await prisma.activity.create({
      data: {
        userId: notification.userId,
        type: `notification_${notification.type}`,
        action: "create",
        metadata: {
          title: notification.title,
          message: notification.message,
          priority: notification.priority,
          data: notification.data,
        },
      },
    });
  }

  // Get email template
  private getEmailTemplate(
    type: string,
    data?: Record<string, any>,
  ): EmailTemplate {
    const templates: Record<string, (data?: any) => EmailTemplate> = {
      welcome: (data) => ({
        subject: "Welcome to TelePrompt Pro!",
        text: `Hi ${data?.name || "there"},\n\nWelcome to TelePrompt Pro! We're excited to have you on board.\n\nGet started by creating your first script.\n\nBest regards,\nThe TelePrompt Pro Team`,
        html: `
          <h1>Welcome to TelePrompt Pro!</h1>
          <p>Hi ${data?.name || "there"},</p>
          <p>We're excited to have you on board. TelePrompt Pro makes creating professional video content easier than ever.</p>
          <p><a href="${process.env.APP_URL}/scripts/new">Create Your First Script</a></p>
          <p>Best regards,<br>The TelePrompt Pro Team</p>
        `,
      }),

      subscription_activated: (data) => ({
        subject: `Your ${data?.plan} Plan is Now Active!`,
        text: `Your ${data?.plan} subscription has been activated. You now have access to all premium features!`,
        html: `
          <h1>Subscription Activated!</h1>
          <p>Your ${data?.plan} plan is now active.</p>
          <p>You now have access to:</p>
          <ul>
            <li>Unlimited cloud-synced scripts</li>
            <li>Voice-activated scrolling</li>
            <li>HD recording</li>
            <li>AI-powered features</li>
          </ul>
          <p><a href="${process.env.APP_URL}/dashboard">Go to Dashboard</a></p>
        `,
      }),

      trial_ending: (data) => ({
        subject: "Your Trial is Ending Soon",
        text: `Your free trial ends in ${data?.daysLeft} days. Upgrade now to continue using premium features.`,
        html: `
          <h1>Your Trial is Ending Soon</h1>
          <p>Your free trial ends in ${data?.daysLeft} days.</p>
          <p>Upgrade now to continue enjoying:</p>
          <ul>
            <li>Unlimited scripts</li>
            <li>Premium features</li>
            <li>Priority support</li>
          </ul>
          <p><a href="${process.env.APP_URL}/pricing">View Pricing</a></p>
        `,
      }),

      payment_failed: (data) => ({
        subject: "Payment Failed - Action Required",
        text: `We couldn't process your payment. Please update your payment method to continue using TelePrompt Pro.`,
        html: `
          <h1>Payment Failed</h1>
          <p>We couldn't process your payment for ${data?.amount}.</p>
          <p>Please update your payment method to avoid service interruption.</p>
          <p><a href="${process.env.APP_URL}/billing">Update Payment Method</a></p>
        `,
      }),

      recording_completed: (data) => ({
        subject: "Your Recording is Ready!",
        text: `Your recording "${data?.title}" has been processed and is ready to download.`,
        html: `
          <h1>Recording Ready!</h1>
          <p>Your recording "${data?.title}" has been successfully processed.</p>
          <p><a href="${process.env.APP_URL}/recordings/${data?.recordingId}">View Recording</a></p>
        `,
      }),

      collaboration_invite: (data) => ({
        subject: `${data?.invitedBy} invited you to collaborate`,
        text: `${data?.invitedBy} has invited you to collaborate on "${data?.scriptTitle}".`,
        html: `
          <h1>Collaboration Invite</h1>
          <p>${data?.invitedBy} has invited you to collaborate on "${data?.scriptTitle}".</p>
          <p><a href="${process.env.APP_URL}/scripts/${data?.scriptId}">View Script</a></p>
        `,
      }),
    };

    const template = templates[type];
    return template
      ? template(data)
      : {
          subject: "Notification from TelePrompt Pro",
          text: data?.message || "You have a new notification",
          html: `<p>${data?.message || "You have a new notification"}</p>`,
        };
  }

  // Batch send notifications
  async sendBatchNotifications(
    notifications: Array<
      Omit<Notification, "id" | "read" | "createdAt">
    >,
  ): Promise<void> {
    const promises = notifications.map((notification) =>
      this.sendNotification(notification),
    );

    await Promise.allSettled(promises);
  }

  // Get user notifications
  async getUserNotifications(
    userId: string,
    options: {
      read?: boolean;
      limit?: number;
      offset?: number;
    } = {},
  ): Promise<any[]> {
    const activities = await prisma.activity.findMany({
      where: {
        userId,
        type: { startsWith: "notification_" },
      },
      orderBy: { createdAt: "desc" },
      take: options.limit || 20,
      skip: options.offset || 0,
    });

    return activities.map((activity) => ({
      id: activity.id,
      type: activity.type.replace("notification_", ""),
      title: (activity.metadata as any)?.title,
      message: (activity.metadata as any)?.message,
      priority: (activity.metadata as any)?.priority,
      data: (activity.metadata as any)?.data,
      read: false, // TODO: Track read status
      createdAt: activity.createdAt,
    }));
  }

  // Mark notification as read
  async markAsRead(notificationId: string): Promise<void> {
    // TODO: Implement read tracking
    console.log(`Marked notification ${notificationId} as read`);
  }

  // Send scheduled notifications
  async sendScheduledNotifications(): Promise<void> {
    // Check for trial endings
    const trialEndingSoon = await this.checkTrialEndings();
    for (const user of trialEndingSoon) {
      await this.sendNotification({
        userId: user.id,
        type: "trial_ending",
        title: "Your Trial is Ending Soon",
        message: `Your trial ends in ${user.daysLeft} days`,
        channel: "email",
        priority: "high",
        data: { daysLeft: user.daysLeft },
      });
    }

    // Check for inactive users
    const inactiveUsers = await this.checkInactiveUsers();
    for (const user of inactiveUsers) {
      await this.sendNotification({
        userId: user.id,
        type: "re_engagement",
        title: "We Miss You!",
        message: "Come back and create amazing content",
        channel: "email",
        priority: "low",
      });
    }
  }

  // Check trial endings
  private async checkTrialEndings(): Promise<Array<{ id: string; daysLeft: number }>> {
    const threeDaysFromNow = new Date();
    threeDaysFromNow.setDate(threeDaysFromNow.getDate() + 3);

    const subscriptions = await prisma.subscription.findMany({
      where: {
        trialEndsAt: {
          gte: new Date(),
          lte: threeDaysFromNow,
        },
        status: "active",
      },
      include: { user: true },
    });

    return subscriptions.map((sub) => ({
      id: sub.userId,
      daysLeft: Math.ceil(
        (sub.trialEndsAt!.getTime() - Date.now()) /
          (1000 * 60 * 60 * 24),
      ),
    }));
  }

  // Check inactive users
  private async checkInactiveUsers(): Promise<Array<{ id: string }>> {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const inactiveUsers = await prisma.user.findMany({
      where: {
        updatedAt: { lte: thirtyDaysAgo },
        subscription: { status: "active" },
      },
      select: { id: true },
    });

    return inactiveUsers;
  }

  // Send notification to multiple users
  async sendBroadcast(
    userIds: string[],
    notification: Omit<
      Notification,
      "id" | "userId" | "read" | "createdAt"
    >,
  ): Promise<void> {
    const notifications = userIds.map((userId) => ({
      ...notification,
      userId,
    }));

    await this.sendBatchNotifications(notifications);
  }
}

export const notificationService = new NotificationService();
