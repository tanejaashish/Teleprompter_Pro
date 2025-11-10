import { OAuth2Client } from "google-auth-library";
import { PrismaClient } from "@prisma/client";
import jwt from "jsonwebtoken";
import { createHash } from "crypto";
import axios from "axios";

// Custom error class
export class AuthenticationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AuthenticationError";
  }
}

const prisma = new PrismaClient();

export class OAuthHandler {
  private googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

  async handleGoogleAuth(idToken: string, accessToken?: string) {
    try {
      // Verify token
      const ticket = await this.googleClient.verifyIdToken({
        idToken,
        audience: process.env.GOOGLE_CLIENT_ID,
      });

      const payload = ticket.getPayload();
      if (!payload) throw new Error("Invalid token payload");

      // Check if user exists
      let user = await prisma.user.findUnique({
        where: { email: payload.email },
      });

      if (!user) {
        // Create new user
        user = await prisma.user.create({
          data: {
            email: payload.email!,
            name: payload.name || "",
            profilePicture: payload.picture,
            provider: "google",
            providerId: payload.sub,
            emailVerified: payload.email_verified || false,
          },
        });

        // Create default subscription
        await this.createDefaultSubscription(user.id);

        // Send welcome email
        await this.sendWelcomeEmail(user);
      } else {
        // Update user info
        await prisma.user.update({
          where: { id: user.id },
          data: {
            lastLogin: new Date(),
            profilePicture: payload.picture,
          },
        });
      }

      // Generate tokens
      const tokens = this.generateTokens(user);

      // Store refresh token
      await this.storeRefreshToken(user.id, tokens.refresh);

      return {
        userId: user.id,
        ...tokens,
      };
    } catch (error) {
      throw new AuthenticationError("Google authentication failed");
    }
  }

  async handleAppleAuth(
    identityToken: string,
    authorizationCode: string,
    userData?: any,
  ) {
    try {
      // Verify identity token
      const decodedToken = jwt.decode(identityToken, { complete: true });

      // Verify token signature with Apple's public key
      const applePublicKey = await this.getApplePublicKey(
        decodedToken.header.kid,
      );
      const verified = jwt.verify(identityToken, applePublicKey);

      // Extract user info
      const { sub, email } = verified as any;

      let user = await prisma.user.findFirst({
        where: {
          OR: [{ providerId: sub }, { email: email }],
        },
      });

      if (!user) {
        user = await prisma.user.create({
          data: {
            email: email || `${sub}@privaterelay.appleid.com`,
            name: userData?.firstName
              ? `${userData.firstName} ${userData.lastName || ""}`.trim()
              : "Apple User",
            provider: "apple",
            providerId: sub,
            emailVerified: true,
          },
        });

        await this.createDefaultSubscription(user.id);
      }

      return {
        userId: user.id,
        ...this.generateTokens(user),
      };
    } catch (error) {
      throw new AuthenticationError("Apple authentication failed");
    }
  }

  private generateTokens(user: any) {
    const accessToken = jwt.sign(
      {
        userId: user.id,
        email: user.email,
        subscription: user.subscription?.tier || "free",
      },
      process.env.JWT_SECRET!,
      { expiresIn: "1h" },
    );

    const refreshToken = jwt.sign(
      { userId: user.id },
      process.env.JWT_REFRESH_SECRET!,
      { expiresIn: "30d" },
    );

    return { accessToken, refreshToken };
  }

  private async createDefaultSubscription(userId: string): Promise<void> {
    await prisma.subscription.create({
      data: {
        userId,
        tier: "free",
        status: "active",
        features: {
          scripts: 10,
          recordingDuration: 300, // 5 minutes
          storage: 1024 * 1024 * 1024, // 1GB
          aiWords: 0,
        },
        limits: {
          maxScripts: 10,
          maxRecordingDuration: 300,
          maxStorageBytes: 1024 * 1024 * 1024,
        },
      },
    });
  }

  private async sendWelcomeEmail(user: any): Promise<void> {
    // TODO: Integrate with email service (SendGrid, AWS SES, etc.)
    console.log(`Welcome email sent to ${user.email}`);

    // Email would include:
    // - Welcome message
    // - Getting started guide
    // - Free tier features overview
    // - Link to upgrade
  }

  private async getApplePublicKey(keyId: string): Promise<string> {
    try {
      // Fetch Apple's public keys
      const response = await axios.get(
        "https://appleid.apple.com/auth/keys",
      );
      const keys = response.data.keys;

      // Find the key matching the kid
      const key = keys.find((k: any) => k.kid === keyId);
      if (!key) {
        throw new Error("Apple public key not found");
      }

      // Convert JWK to PEM format
      // Note: In production, use a library like jwk-to-pem
      return this.jwkToPem(key);
    } catch (error) {
      throw new AuthenticationError("Failed to fetch Apple public key");
    }
  }

  private jwkToPem(jwk: any): string {
    // This is a simplified version
    // In production, use a proper library like 'jwk-to-pem'
    // For now, return a placeholder that would work with jwt.verify
    return jwk.n; // This is incomplete - use jwk-to-pem library in production
  }

  private async storeRefreshToken(
    userId: string,
    refreshToken: string,
  ): Promise<void> {
    // Hash the refresh token for security
    const hashedToken = createHash("sha256")
      .update(refreshToken)
      .digest("hex");

    // Store in database or Redis
    // Using Redis for session management
    const Redis = require("ioredis");
    const redis = new Redis(process.env.REDIS_URL);

    await redis.set(
      `refresh_token:${userId}`,
      hashedToken,
      "EX",
      30 * 24 * 60 * 60, // 30 days
    );
  }

  // Microsoft OAuth handler
  async handleMicrosoftAuth(
    accessToken: string,
    idToken?: string,
  ): Promise<any> {
    try {
      // Verify token with Microsoft Graph API
      const userInfoResponse = await axios.get(
        "https://graph.microsoft.com/v1.0/me",
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        },
      );

      const userData = userInfoResponse.data;

      // Find or create user
      let user = await prisma.user.findFirst({
        where: {
          OR: [
            { microsoftId: userData.id },
            { email: userData.mail || userData.userPrincipalName },
          ],
        },
        include: { subscription: true },
      });

      if (!user) {
        // Create new user
        user = await prisma.user.create({
          data: {
            email: userData.mail || userData.userPrincipalName,
            displayName: userData.displayName,
            microsoftId: userData.id,
            emailVerified: true,
            photoUrl: null, // Microsoft Graph doesn't provide photo URL directly
            metadata: {
              microsoftData: {
                jobTitle: userData.jobTitle,
                officeLocation: userData.officeLocation,
                department: userData.department,
              },
            },
          },
          include: { subscription: true },
        });

        // Create default subscription
        await this.createDefaultSubscription(user.id);

        // Send welcome email
        await this.sendWelcomeEmail(user);
      } else {
        // Update user info
        user = await prisma.user.update({
          where: { id: user.id },
          data: {
            updatedAt: new Date(),
            displayName: userData.displayName || user.displayName,
          },
          include: { subscription: true },
        });
      }

      // Generate tokens
      const tokens = this.generateTokens(user);

      // Store refresh token
      await this.storeRefreshToken(user.id, tokens.refreshToken);

      return {
        userId: user.id,
        ...tokens,
      };
    } catch (error: any) {
      console.error("Microsoft OAuth error:", error);
      throw new AuthenticationError(
        `Microsoft authentication failed: ${error.message || "Unknown error"}`,
      );
    }
  }
}
