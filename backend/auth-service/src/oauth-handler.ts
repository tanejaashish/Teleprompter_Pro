import { OAuth2Client } from "google-auth-library";
import jwt from "jsonwebtoken";

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

  private generateTokens(user: User) {
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
}
