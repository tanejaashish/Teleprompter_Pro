import { PrismaClient } from "@prisma/client";
import Stripe from "stripe";
import { RevenueCatClient } from "./revenuecat-client";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2023-10-16",
  typescript: true,
});

const prisma = new PrismaClient();
const revenueCat = new RevenueCatClient(process.env.REVENUECAT_API_KEY!);

export class AdvancedPaymentService {
  // Pricing configuration
  private readonly pricing = {
    advanced: {
      monthly: {
        priceId: process.env.STRIPE_PRICE_ADVANCED_MONTHLY!,
        amount: 1900, // $19.00
      },
      yearly: {
        priceId: process.env.STRIPE_PRICE_ADVANCED_YEARLY!,
        amount: 19000, // $190.00 (2 months free)
      },
    },
    pro: {
      monthly: {
        priceId: process.env.STRIPE_PRICE_PRO_MONTHLY!,
        amount: 4900, // $49.00
      },
      yearly: {
        priceId: process.env.STRIPE_PRICE_PRO_YEARLY!,
        amount: 49000, // $490.00 (2 months free)
      },
    },
    team: {
      monthly: {
        priceId: process.env.STRIPE_PRICE_TEAM_MONTHLY!,
        amount: 19900, // $199.00
      },
      yearly: {
        priceId: process.env.STRIPE_PRICE_TEAM_YEARLY!,
        amount: 199000, // $1990.00
      },
    },
  };

  // Create advanced checkout session
  async createCheckoutSession(params: {
    userId: string;
    plan: "advanced" | "pro" | "team";
    interval: "monthly" | "yearly";
    successUrl: string;
    cancelUrl: string;
    quantity?: number;
    couponCode?: string;
    trialDays?: number;
  }): Promise<Stripe.Checkout.Session> {
    const user = await prisma.user.findUnique({
      where: { id: params.userId },
      include: { subscription: true },
    });

    if (!user) throw new Error("User not found");

    // Get or create Stripe customer
    let customerId = user.stripeCustomerId;
    if (!customerId) {
      customerId = await this.createStripeCustomer(user);
    }

    // Check for existing subscription
    if (user.subscription?.status === "active") {
      // Handle upgrade/downgrade
      return await this.createUpgradeSession(params, user.subscription);
    }

    // Build line items
    const lineItems: Stripe.Checkout.SessionCreateParams.LineItem[] = [
      {
        price: this.pricing[params.plan][params.interval].priceId,
        quantity: params.quantity || 1,
      },
    ];

    // Create session parameters
    const sessionParams: Stripe.Checkout.SessionCreateParams = {
      customer: customerId,
      payment_method_types: ["card", "us_bank_account"],
      line_items: lineItems,
      mode: "subscription",
      success_url: params.successUrl,
      cancel_url: params.cancelUrl,
      allow_promotion_codes: !params.couponCode,
      subscription_data: {
        trial_period_days: params.trialDays || (params.plan === "pro" ? 14 : 7),
        metadata: {
          userId: params.userId,
          plan: params.plan,
          interval: params.interval,
        },
      },
      metadata: {
        userId: params.userId,
      },
      billing_address_collection: "required",
      tax_id_collection: {
        enabled: true,
      },
      automatic_tax: {
        enabled: true,
      },
      customer_update: {
        address: "auto",
        name: "auto",
      },
    };

    // Apply coupon if provided
    if (params.couponCode) {
      sessionParams.discounts = [
        {
          coupon: params.couponCode,
        },
      ];
    }

    // Add team-specific features
    if (params.plan === "team") {
      sessionParams.subscription_data!.items = [
        {
          price: this.pricing.team[params.interval].priceId,
          quantity: params.quantity || 5, // Default 5 seats
          adjustable_quantity: {
            enabled: true,
            minimum: 5,
            maximum: 50,
          },
        },
      ];
    }

    return await stripe.checkout.sessions.create(sessionParams);
  }

  // Handle subscription lifecycle
  async handleSubscriptionWebhook(event: Stripe.Event): Promise<void> {
    switch (event.type) {
      case "checkout.session.completed":
        await this.handleCheckoutComplete(
          event.data.object as Stripe.Checkout.Session,
        );
        break;

      case "customer.subscription.created":
      case "customer.subscription.updated":
        await this.handleSubscriptionUpdate(
          event.data.object as Stripe.Subscription,
        );
        break;

      case "customer.subscription.deleted":
        await this.handleSubscriptionCanceled(
          event.data.object as Stripe.Subscription,
        );
        break;

      case "customer.subscription.trial_will_end":
        await this.handleTrialEnding(event.data.object as Stripe.Subscription);
        break;

      case "invoice.payment_succeeded":
        await this.handlePaymentSuccess(event.data.object as Stripe.Invoice);
        break;

      case "invoice.payment_failed":
        await this.handlePaymentFailed(event.data.object as Stripe.Invoice);
        break;

      case "customer.subscription.paused":
        await this.handleSubscriptionPaused(
          event.data.object as Stripe.Subscription,
        );
        break;
    }
  }

  private async handleCheckoutComplete(
    session: Stripe.Checkout.Session,
  ): Promise<void> {
    const userId = session.metadata?.userId;
    if (!userId) return;

    const subscription = await stripe.subscriptions.retrieve(
      session.subscription as string,
      { expand: ["items.data.price.product"] },
    );

    // Update database
    await prisma.subscription.upsert({
      where: { userId },
      create: {
        userId,
        stripeSubscriptionId: subscription.id,
        stripeCustomerId: subscription.customer as string,
        stripePriceId: subscription.items.data[0].price.id,
        tier: this.getTierFromPriceId(subscription.items.data[0].price.id),
        status: subscription.status as any,
        currentPeriodStart: new Date(subscription.current_period_start * 1000),
        currentPeriodEnd: new Date(subscription.current_period_end * 1000),
        cancelAtPeriodEnd: subscription.cancel_at_period_end,
        metadata: {
          seats: subscription.items.data[0].quantity,
          interval: subscription.items.data[0].price.recurring?.interval,
        } as any,
      },
      update: {
        stripeSubscriptionId: subscription.id,
        stripePriceId: subscription.items.data[0].price.id,
        tier: this.getTierFromPriceId(subscription.items.data[0].price.id),
        status: subscription.status as any,
        currentPeriodStart: new Date(subscription.current_period_start * 1000),
        currentPeriodEnd: new Date(subscription.current_period_end * 1000),
        cancelAtPeriodEnd: subscription.cancel_at_period_end,
      },
    });

    // Sync with RevenueCat for mobile
    await revenueCat.syncPurchase(userId, subscription);

    // Grant immediate access
    await this.grantAccess(userId, subscription);

    // Send welcome email
    await this.sendWelcomeEmail(userId, subscription);

    // Track analytics
    await this.trackSubscriptionEvent("subscription_created", {
      userId,
      plan: this.getTierFromPriceId(subscription.items.data[0].price.id),
      revenue: subscription.items.data[0].price.unit_amount,
    });
  }

  // Usage-based billing for AI features
  async trackUsageAndBill(
    userId: string,
    feature: "ai_generation" | "transcription" | "eye_correction",
    quantity: number,
  ): Promise<void> {
    const subscription = await prisma.subscription.findUnique({
      where: { userId },
    });

    if (!subscription) return;

    // Check if within included quota
    const usage = await prisma.usageRecord.findFirst({
      where: {
        userId,
        feature,
        periodStart: subscription.currentPeriodStart,
        periodEnd: subscription.currentPeriodEnd,
      },
    });

    const currentUsage = (usage?.quantity || 0) + quantity;
    const includedQuota = this.getIncludedQuota(subscription.tier, feature);

    // Update usage record
    await prisma.usageRecord.upsert({
      where: {
        userId_feature_periodStart: {
          userId,
          feature,
          periodStart: subscription.currentPeriodStart,
        },
      },
      create: {
        userId,
        feature,
        quantity: currentUsage,
        periodStart: subscription.currentPeriodStart,
        periodEnd: subscription.currentPeriodEnd,
      },
      update: {
        quantity: currentUsage,
      },
    });

    // Bill for overage if applicable
    if (currentUsage > includedQuota && subscription.tier === "pro") {
      const overage = currentUsage - includedQuota;
      const unitPrice = this.getOveragePrice(feature);

      await stripe.subscriptionItems.createUsageRecord(
        subscription.stripeSubscriptionId!,
        {
          quantity: overage,
          timestamp: Math.floor(Date.now() / 1000),
          action: "increment",
        },
      );
    }
  }

  // Customer portal for self-service
  async createCustomerPortalSession(
    userId: string,
    returnUrl: string,
  ): Promise<string> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user?.stripeCustomerId) {
      throw new Error("No Stripe customer found");
    }

    const session = await stripe.billingPortal.sessions.create({
      customer: user.stripeCustomerId,
      return_url: returnUrl,
    });

    return session.url;
  }

  private getTierFromPriceId(priceId: string): string {
    for (const [tier, intervals] of Object.entries(this.pricing)) {
      for (const [_, config] of Object.entries(intervals)) {
        if (config.priceId === priceId) {
          return tier;
        }
      }
    }
    return "free";
  }

  private getIncludedQuota(tier: string, feature: string): number {
    const quotas: Record<string, Record<string, number>> = {
      advanced: {
        ai_generation: 1000,
        transcription: 0,
        eye_correction: 0,
      },
      pro: {
        ai_generation: 999999,
        transcription: 600, // 10 hours in minutes
        eye_correction: 100,
      },
      team: {
        ai_generation: 999999,
        transcription: 3000, // 50 hours
        eye_correction: 500,
      },
    };

    return quotas[tier]?.[feature] || 0;
  }
}
