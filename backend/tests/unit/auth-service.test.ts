// Comprehensive Test Suite - Auth Service
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { OAuthHandler, AuthenticationError } from '../../auth-service/src/oauth-handler';

jest.mock('@prisma/client');
jest.mock('google-auth-library');

describe('OAuthHandler', () => {
  let authHandler: OAuthHandler;
  let mockPrisma: any;

  beforeEach(() => {
    authHandler = new OAuthHandler();
    mockPrisma = {
      user: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      subscription: {
        create: jest.fn(),
      },
    };
  });

  describe('handleGoogleAuth', () => {
    it('should create new user on first Google login', async () => {
      const mockPayload = {
        sub: 'google_123',
        email: 'test@example.com',
        name: 'Test User',
        picture: 'https://example.com/photo.jpg',
        email_verified: true,
      };

      mockPrisma.user.findUnique.mockResolvedValue(null);
      mockPrisma.user.create.mockResolvedValue({
        id: 'user_123',
        email: 'test@example.com',
      });

      const result = await authHandler.handleGoogleAuth('mock_token');

      expect(result).toBeDefined();
      expect(result.userId).toBe('user_123');
      expect(result.accessToken).toBeDefined();
      expect(result.refreshToken).toBeDefined();
    });

    it('should return existing user on subsequent login', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'user_123',
        email: 'test@example.com',
      });

      mockPrisma.user.update.mockResolvedValue({});

      const result = await authHandler.handleGoogleAuth('mock_token');

      expect(result).toBeDefined();
      expect(mockPrisma.user.update).toHaveBeenCalled();
    });

    it('should throw AuthenticationError on invalid token', async () => {
      await expect(authHandler.handleGoogleAuth('invalid_token')).rejects.toThrow(
        AuthenticationError,
      );
    });
  });

  describe('handleAppleAuth', () => {
    it('should handle Apple Sign In', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(null);
      mockPrisma.user.create.mockResolvedValue({
        id: 'user_123',
        email: 'test@privaterelay.appleid.com',
      });

      const result = await authHandler.handleAppleAuth(
        'mock_identity_token',
        'mock_code',
        {
          firstName: 'Test',
          lastName: 'User',
        },
      );

      expect(result).toBeDefined();
      expect(mockPrisma.user.create).toHaveBeenCalled();
    });
  });

  describe('handleMicrosoftAuth', () => {
    it('should create user from Microsoft account', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(null);
      mockPrisma.user.create.mockResolvedValue({
        id: 'user_123',
        email: 'test@company.com',
      });

      const result = await authHandler.handleMicrosoftAuth('mock_access_token');

      expect(result).toBeDefined();
      expect(result.userId).toBe('user_123');
    });

    it('should update existing Microsoft user', async () => {
      mockPrisma.user.findFirst.mockResolvedValue({
        id: 'user_123',
        email: 'test@company.com',
        microsoftId: 'ms_123',
      });

      mockPrisma.user.update.mockResolvedValue({});

      const result = await authHandler.handleMicrosoftAuth('mock_access_token');

      expect(mockPrisma.user.update).toHaveBeenCalled();
    });
  });

  describe('generateTokens', () => {
    it('should generate valid JWT tokens', () => {
      const user = {
        id: 'user_123',
        email: 'test@example.com',
        subscription: { tier: 'pro' },
      };

      const tokens = (authHandler as any).generateTokens(user);

      expect(tokens.accessToken).toBeDefined();
      expect(tokens.refreshToken).toBeDefined();
      expect(typeof tokens.accessToken).toBe('string');
      expect(typeof tokens.refreshToken).toBe('string');
    });
  });
});
