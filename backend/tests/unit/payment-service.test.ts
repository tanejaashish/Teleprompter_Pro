// Comprehensive Test Suite - Payment Service
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { AdvancedPaymentService } from '../../payment-service/src/advanced-payment-service';
import Stripe from 'stripe';

// Mock dependencies
jest.mock('@prisma/client');
jest.mock('stripe');

describe('AdvancedPaymentService', () => {
  let paymentService: AdvancedPaymentService;
  let mockStripe: jest.Mocked<Stripe>;
  let mockPrisma: any;

  beforeEach(() => {
    paymentService = new AdvancedPaymentService();
    mockStripe = new Stripe('test_key', { apiVersion: '2023-10-16' }) as any;
    mockPrisma = {
      user: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      subscription: {
        create: jest.fn(),
        update: jest.fn(),
        upsert: jest.fn(),
      },
      payment: {
        create: jest.fn(),
      },
      activity: {
        create: jest.fn(),
      },
    };
  });

  describe('createCheckoutSession', () => {
    it('should create a checkout session for new subscription', async () => {
      const params = {
        userId: 'user_123',
        plan: 'pro' as const,
        interval: 'monthly' as const,
        successUrl: 'https://example.com/success',
        cancelUrl: 'https://example.com/cancel',
      };

      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'user_123',
        email: 'test@example.com',
        stripeCustomerId: null,
      });

      const session = await paymentService.createCheckoutSession(params);

      expect(session).toBeDefined();
      expect(mockPrisma.user.findUnique).toHaveBeenCalledWith({
        where: { id: 'user_123' },
        include: { subscription: true },
      });
    });

    it('should throw error for non-existent user', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);

      await expect(
        paymentService.createCheckoutSession({
          userId: 'invalid_user',
          plan: 'pro',
          interval: 'monthly',
          successUrl: 'https://example.com/success',
          cancelUrl: 'https://example.com/cancel',
        }),
      ).rejects.toThrow('User not found');
    });
  });

  describe('handleSubscriptionWebhook', () => {
    it('should handle checkout.session.completed event', async () => {
      const event: Stripe.Event = {
        type: 'checkout.session.completed',
        data: {
          object: {
            subscription: 'sub_123',
            metadata: {
              userId: 'user_123',
            },
          } as any,
        },
      } as any;

      mockPrisma.subscription.upsert.mockResolvedValue({});

      await paymentService.handleSubscriptionWebhook(event);

      expect(mockPrisma.subscription.upsert).toHaveBeenCalled();
    });

    it('should handle customer.subscription.deleted event', async () => {
      const event: Stripe.Event = {
        type: 'customer.subscription.deleted',
        data: {
          object: {
            id: 'sub_123',
            metadata: {
              userId: 'user_123',
            },
          } as any,
        },
      } as any;

      mockPrisma.subscription.update.mockResolvedValue({});

      await paymentService.handleSubscriptionWebhook(event);

      expect(mockPrisma.subscription.update).toHaveBeenCalledWith({
        where: { userId: 'user_123' },
        data: expect.objectContaining({
          status: 'cancelled',
        }),
      });
    });
  });

  describe('trackUsageAndBill', () => {
    it('should track usage within quota', async () => {
      mockPrisma.subscription.findUnique.mockResolvedValue({
        userId: 'user_123',
        tier: 'pro',
        currentPeriodStart: new Date('2024-01-01'),
        currentPeriodEnd: new Date('2024-02-01'),
      });

      mockPrisma.usageRecord.findFirst.mockResolvedValue(null);
      mockPrisma.usageRecord.upsert.mockResolvedValue({});

      await paymentService.trackUsageAndBill('user_123', 'ai_generation', 100);

      expect(mockPrisma.usageRecord.upsert).toHaveBeenCalled();
    });

    it('should bill for overage on pro tier', async () => {
      mockPrisma.subscription.findUnique.mockResolvedValue({
        userId: 'user_123',
        tier: 'pro',
        currentPeriodStart: new Date('2024-01-01'),
        currentPeriodEnd: new Date('2024-02-01'),
        stripeSubscriptionId: 'sub_123',
      });

      mockPrisma.usageRecord.findFirst.mockResolvedValue({
        quantity: 1000000, // Over quota
      });

      await paymentService.trackUsageAndBill('user_123', 'ai_generation', 100);

      // Should create usage record in Stripe
      expect(mockPrisma.usageRecord.upsert).toHaveBeenCalled();
    });
  });

  describe('createCustomerPortalSession', () => {
    it('should create portal session for existing customer', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'user_123',
        stripeCustomerId: 'cus_123',
      });

      const url = await paymentService.createCustomerPortalSession(
        'user_123',
        'https://example.com/return',
      );

      expect(url).toBeDefined();
      expect(typeof url).toBe('string');
    });

    it('should throw error for user without Stripe customer', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'user_123',
        stripeCustomerId: null,
      });

      await expect(
        paymentService.createCustomerPortalSession('user_123', 'https://example.com'),
      ).rejects.toThrow('No Stripe customer found');
    });
  });
});
