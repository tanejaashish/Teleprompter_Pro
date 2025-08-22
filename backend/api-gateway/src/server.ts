// backend/api-gateway/src/server.ts

import { PrismaClient } from "@prisma/client";
import bcrypt from "bcrypt";
import cors from "cors";
import dotenv from "dotenv";
import type { Express, NextFunction, Request, Response } from "express";
import express from "express";
import rateLimit from "express-rate-limit";
import { OAuth2Client } from "google-auth-library";
import helmet from "helmet";
import { createServer } from "http";
import Redis from "ioredis";
import jwt from "jsonwebtoken";
import path from "path";
import { Server as SocketIOServer } from "socket.io";

// Load environment variables
//dotenv.config();
dotenv.config({ path: path.join(__dirname, "../.env") });

// Initialize core services
const app: Express = express();
const httpServer = createServer(app);
const io = new SocketIOServer(httpServer, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS?.split(",") || [
      "http://localhost:3000",
    ],
    credentials: true,
  },
});

const prisma = new PrismaClient();
const redis = new Redis(process.env.REDIS_URL || "redis://localhost:6379");
const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// ============================================
// Type Definitions
// ============================================

interface AuthRequest extends Request {
  user?: {
    id: string;
    email: string;
    subscriptionTier?: string;
  };
}

interface TokenPayload {
  id: string;
  email: string;
  iat?: number;
  exp?: number;
}

// ============================================
// Middleware Configuration
// ============================================

// Security headers
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", "data:", "https:"],
      },
    },
  }),
);

// CORS configuration
app.use(
  cors({
    origin: (origin, callback) => {
      const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(",") || [
        "http://localhost:3000",
      ];
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error("Not allowed by CORS"));
      }
    },
    credentials: true,
  }),
);

// Body parsing
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true, limit: "50mb" }));

// Rate limiting configurations
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: "Too many requests from this IP, please try again later.",
  standardHeaders: true,
  legacyHeaders: false,
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5, // strict limit for auth endpoints
  skipSuccessfulRequests: true,
  message: "Too many authentication attempts, please try again later.",
});

const uploadLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 10, // 10 uploads per hour
  message: "Upload limit exceeded, please try again later.",
});

// Apply rate limiters
app.use("/api/", generalLimiter);
app.use("/api/auth/", authLimiter);
app.use("/api/upload/", uploadLimiter);

// ============================================
// Authentication Middleware
// ============================================

const authenticateToken = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) {
    res.status(401).json({ error: "Access token required" });
    return;
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as TokenPayload;

    // Check if token exists in Redis (not blacklisted)
    const isBlacklisted = await redis.get(`blacklist:${token}`);
    if (isBlacklisted) {
      res.status(401).json({ error: "Token has been revoked" });
      return;
    }

    // Get user from database
    const user = await prisma.user.findUnique({
      where: { id: payload.id },
      include: { subscription: true },
    });

    if (!user) {
      res.status(401).json({ error: "User not found" });
      return;
    }

    req.user = {
      id: user.id,
      email: user.email,
      subscriptionTier: user.subscription?.tier || "free",
    };

    next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      res.status(401).json({ error: "Token expired" });
    } else if (error instanceof jwt.JsonWebTokenError) {
      res.status(403).json({ error: "Invalid token" });
    } else {
      res.status(500).json({ error: "Token verification failed" });
    }
  }
};

// Subscription tier authorization
const requireSubscription = (minTier: string) => {
  return async (
    req: AuthRequest,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    if (!req.user) {
      res.status(401).json({ error: "Authentication required" });
      return;
    }

    const tierOrder = ["free", "creator", "professional", "enterprise"];
    const userTierIndex = tierOrder.indexOf(
      req.user.subscriptionTier || "free",
    );
    const requiredTierIndex = tierOrder.indexOf(minTier);

    if (userTierIndex < requiredTierIndex) {
      res.status(403).json({
        error: `This feature requires ${minTier} subscription or higher`,
        currentTier: req.user.subscriptionTier,
        requiredTier: minTier,
      });
      return;
    }

    next();
  };
};

// ============================================
// Authentication Routes
// ============================================

// Sign up
app.post("/api/auth/signup", async (req: Request, res: Response) => {
  try {
    const { email, password, displayName } = req.body;

    // Validate input
    if (!email || !password) {
      res.status(400).json({ error: "Email and password are required" });
      return;
    }

    // Check if user exists
    const existingUser = await prisma.user.findUnique({
      where: { email },
    });

    if (existingUser) {
      res.status(400).json({ error: "Email already registered" });
      return;
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user with free subscription
    const user = await prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        displayName,
        subscription: {
          create: {
            tier: "free",
            status: "active",
          },
        },
      },
      include: {
        subscription: true,
      },
    });

    // Generate tokens
    const accessToken = jwt.sign(
      { id: user.id, email: user.email },
      process.env.JWT_SECRET!,
      { expiresIn: "1h" },
    );

    const refreshToken = jwt.sign(
      { id: user.id },
      process.env.JWT_REFRESH_SECRET!,
      { expiresIn: "30d" },
    );

    // Store refresh token in Redis
    await redis.set(
      `refresh:${user.id}`,
      refreshToken,
      "EX",
      30 * 24 * 60 * 60, // 30 days
    );

    // Log activity
    await prisma.activity.create({
      data: {
        userId: user.id,
        type: "user_signup",
        action: "create",
        metadata: { method: "email" },
      },
    });

    res.status(201).json({
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        subscriptionTier: user.subscription?.tier,
        createdAt: user.createdAt,
      },
      session: {
        accessToken,
        refreshToken,
        expiresAt: new Date(Date.now() + 60 * 60 * 1000),
      },
    });
  } catch (error) {
    console.error("Signup error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Sign in
app.post("/api/auth/signin", async (req: Request, res: Response) => {
  try {
    const { email, password, deviceId, deviceName } = req.body;

    // Find user
    const user = await prisma.user.findUnique({
      where: { email },
      include: { subscription: true },
    });

    if (!user || !user.password) {
      res.status(401).json({ error: "Invalid credentials" });
      return;
    }

    // Verify password
    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
      res.status(401).json({ error: "Invalid credentials" });
      return;
    }

    // Generate tokens
    const accessToken = jwt.sign(
      { id: user.id, email: user.email },
      process.env.JWT_SECRET!,
      { expiresIn: "1h" },
    );

    const refreshToken = jwt.sign(
      { id: user.id },
      process.env.JWT_REFRESH_SECRET!,
      { expiresIn: "30d" },
    );

    // Store refresh token
    await redis.set(
      `refresh:${user.id}`,
      refreshToken,
      "EX",
      30 * 24 * 60 * 60,
    );

    // Create session record - FIXED: Changed 'token' to 'accessToken'
    const session = await prisma.session.create({
      data: {
        userId: user.id,
        token: accessToken, // FIXED: was 'token' which was undefined
        refreshToken,
        deviceId: req.body.deviceId || "unknown",
        deviceName: req.body.deviceName || "Unknown Device",
        deviceType: req.body.deviceType || "web",
        platform: req.body.platform || "web",
        ipAddress: req.ip || null,
        userAgent: req.get("user-agent") || null,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      },
    });

    // Log activity
    await prisma.activity.create({
      data: {
        userId: user.id,
        type: "user_signin",
        action: "create",
        metadata: { deviceId, deviceName },
      },
    });

    res.json({
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        subscriptionTier: user.subscription?.tier,
      },
      session: {
        accessToken,
        refreshToken,
        expiresAt: new Date(Date.now() + 60 * 60 * 1000),
      },
    });
  } catch (error) {
    console.error("Signin error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Google OAuth
app.post("/api/auth/oauth/google", async (req: Request, res: Response) => {
  try {
    const { idToken } = req.body;

    // Verify Google token - FIXED: Added non-null assertion
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID!,
    });

    const payload = ticket.getPayload();
    if (!payload) {
      res.status(401).json({ error: "Invalid Google token" });
      return;
    }

    // Find or create user
    let user = await prisma.user.findUnique({
      where: { googleId: payload.sub },
      include: { subscription: true },
    });

    if (!user) {
      user = await prisma.user.create({
        data: {
          email: payload.email!,
          googleId: payload.sub,
          displayName: payload.name,
          photoUrl: payload.picture,
          emailVerified: payload.email_verified || false,
          subscription: {
            create: {
              tier: "free",
              status: "active",
            },
          },
        },
        include: { subscription: true },
      });
    }

    // Generate tokens
    const accessToken = jwt.sign(
      { id: user.id, email: user.email },
      process.env.JWT_SECRET!,
      { expiresIn: "1h" },
    );

    const refreshToken = jwt.sign(
      { id: user.id },
      process.env.JWT_REFRESH_SECRET!,
      { expiresIn: "30d" },
    );

    res.json({
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoUrl,
        subscriptionTier: user.subscription?.tier,
      },
      session: {
        accessToken,
        refreshToken,
        expiresAt: new Date(Date.now() + 60 * 60 * 1000),
      },
    });
  } catch (error) {
    console.error("Google OAuth error:", error);
    res.status(500).json({ error: "OAuth authentication failed" });
  }
});

// Refresh token
app.post("/api/auth/refresh", async (req: Request, res: Response) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      res.status(401).json({ error: "Refresh token required" });
      return;
    }

    // Verify refresh token
    const payload = jwt.verify(
      refreshToken,
      process.env.JWT_REFRESH_SECRET!,
    ) as TokenPayload;

    // Check if refresh token is valid in Redis
    const storedToken = await redis.get(`refresh:${payload.id}`);
    if (storedToken !== refreshToken) {
      res.status(401).json({ error: "Invalid refresh token" });
      return;
    }

    // Generate new access token
    const accessToken = jwt.sign({ id: payload.id }, process.env.JWT_SECRET!, {
      expiresIn: "1h",
    });

    res.json({
      accessToken,
      expiresAt: new Date(Date.now() + 60 * 60 * 1000),
    });
  } catch (error) {
    res.status(401).json({ error: "Invalid refresh token" });
  }
});

// Sign out
app.post(
  "/api/auth/signout",
  authenticateToken,
  async (req: AuthRequest, res: Response) => {
    try {
      const authHeader = req.headers["authorization"];
      const token = authHeader && authHeader.split(" ")[1];

      if (token) {
        // Blacklist the current access token
        await redis.set(
          `blacklist:${token}`,
          "1",
          "EX",
          60 * 60, // 1 hour (token expiry time)
        );
      }

      // Remove refresh token
      if (req.user) {
        await redis.del(`refresh:${req.user.id}`);
      }

      res.json({ message: "Signed out successfully" });
    } catch (error) {
      res.status(500).json({ error: "Sign out failed" });
    }
  },
);

// ============================================
// Script Management Routes
// ============================================

// Get all scripts for user
app.get(
  "/api/scripts",
  authenticateToken,
  async (req: AuthRequest, res: Response) => {
    try {
      const scripts = await prisma.script.findMany({
        where: {
          userId: req.user!.id,
          deletedAt: null,
        },
        orderBy: { updatedAt: "desc" },
        select: {
          id: true,
          title: true,
          content: true,
          wordCount: true,
          estimatedDuration: true,
          category: true,
          tags: true,
          createdAt: true,
          updatedAt: true,
        },
      });

      res.json(scripts);
    } catch (error) {
      console.error("Get scripts error:", error);
      res.status(500).json({ error: "Failed to fetch scripts" });
    }
  },
);

// Create new script
app.post(
  "/api/scripts",
  authenticateToken,
  async (req: AuthRequest, res: Response) => {
    try {
      const { title, content, richContent, category, tags, settings } =
        req.body;

      // Calculate metrics
      const wordCount = content
        .split(/\s+/)
        .filter((word: string) => word.length > 0).length;
      const estimatedDuration = Math.ceil(wordCount / 150) * 60; // 150 WPM average

      const script = await prisma.script.create({
        data: {
          userId: req.user!.id,
          title,
          content,
          richContent,
          wordCount,
          characterCount: content.length,
          estimatedDuration,
          category,
          tags,
          settings: settings || {},
        },
      });

      // Log activity
      await prisma.activity.create({
        data: {
          userId: req.user!.id,
          type: "script_created",
          action: "create",
          entityType: "script",
          entityId: script.id,
          entityTitle: script.title,
        },
      });

      // Emit to connected clients for real-time sync
      io.to(`user:${req.user!.id}`).emit("script:created", script);

      res.status(201).json(script);
    } catch (error) {
      console.error("Create script error:", error);
      res.status(500).json({ error: "Failed to create script" });
    }
  },
);

// Update script
app.put(
  "/api/scripts/:id",
  authenticateToken,
  async (req: AuthRequest, res: Response) => {
    try {
      const { id } = req.params;
      const { title, content, richContent, category, tags, settings } =
        req.body;

      // Check ownership - FIXED: Added type assertion
      const existingScript = await prisma.script.findFirst({
        where: {
          id: id as string,
          userId: req.user!.id,
        },
      });

      if (!existingScript) {
        res.status(404).json({ error: "Script not found" });
        return;
      }

      // Update script
      const wordCount = content
        .split(/\s+/)
        .filter((word: string) => word.length > 0).length;
      const estimatedDuration = Math.ceil(wordCount / 150) * 60;

      // FIXED: Added type assertion
      const script = await prisma.script.update({
        where: { id: id as string },
        data: {
          title,
          content,
          richContent,
          wordCount,
          characterCount: content.length,
          estimatedDuration,
          category,
          tags,
          settings,
          updatedAt: new Date(),
        },
      });

      // Create version history (for Pro users)
      if (
        req.user!.subscriptionTier === "professional" ||
        req.user!.subscriptionTier === "enterprise"
      ) {
        // FIXED: Added type assertion
        const latestVersion = await prisma.scriptVersion.findFirst({
          where: { scriptId: id as string },
          orderBy: { version: "desc" },
        });

        // FIXED: Added type assertion
        await prisma.scriptVersion.create({
          data: {
            scriptId: id as string,
            version: (latestVersion?.version || 0) + 1,
            content: existingScript.content,
            richContent: existingScript.richContent,
            createdBy: req.user!.id,
          },
        });
      }

      // Emit update
      io.to(`user:${req.user!.id}`).emit("script:updated", script);

      res.json(script);
    } catch (error) {
      console.error("Update script error:", error);
      res.status(500).json({ error: "Failed to update script" });
    }
  },
);

// Delete script
app.delete(
  "/api/scripts/:id",
  authenticateToken,
  async (req: AuthRequest, res: Response) => {
    try {
      const { id } = req.params;

      // Soft delete - FIXED: Added type assertion
      await prisma.script.update({
        where: { id: id as string },
        data: { deletedAt: new Date() },
      });

      // Emit deletion
      io.to(`user:${req.user!.id}`).emit("script:deleted", { id });

      res.json({ message: "Script deleted successfully" });
    } catch (error) {
      console.error("Delete script error:", error);
      res.status(500).json({ error: "Failed to delete script" });
    }
  },
);

// ============================================
// WebSocket Sync
// ============================================

io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth.token;
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as TokenPayload;
    socket.data.userId = payload.id;
    next();
  } catch (err) {
    next(new Error("Authentication failed"));
  }
});

io.on("connection", (socket) => {
  console.log("Client connected:", socket.data.userId);

  // Join user room for targeted updates
  socket.join(`user:${socket.data.userId}`);

  // Handle sync events
  socket.on("sync:request", async () => {
    // Send all user's data for initial sync
    const [scripts, recordings] = await Promise.all([
      prisma.script.findMany({
        where: { userId: socket.data.userId, deletedAt: null },
      }),
      prisma.recording.findMany({
        where: { userId: socket.data.userId, deletedAt: null },
      }),
    ]);

    socket.emit("sync:data", { scripts, recordings });
  });

  socket.on("disconnect", () => {
    console.log("Client disconnected:", socket.data.userId);
  });
});

// ============================================
// Health & Monitoring Routes
// ============================================

app.get("/api/health", async (req: Request, res: Response) => {
  try {
    // Check database connection
    await prisma.$queryRaw`SELECT 1`;

    // Check Redis connection
    await redis.ping();

    res.json({
      status: "healthy",
      timestamp: new Date().toISOString(),
      services: {
        database: "connected",
        redis: "connected",
        websocket: io.engine.clientsCount > 0 ? "active" : "idle",
      },
      version: process.env.npm_package_version || "1.0.0",
    });
  } catch (error) {
    res.status(503).json({
      status: "unhealthy",
      error: "Service unavailable",
      timestamp: new Date().toISOString(),
    });
  }
});

app.get(
  "/api/metrics",
  authenticateToken,
  requireSubscription("enterprise"),
  async (req: AuthRequest, res: Response) => {
    // Enterprise-only metrics endpoint
    const metrics = {
      users: await prisma.user.count(),
      scripts: await prisma.script.count(),
      recordings: await prisma.recording.count(),
      activeSubscriptions: await prisma.subscription.count({
        where: { status: "active" },
      }),
    };

    res.json(metrics);
  },
);

// ============================================
// Error Handling
// ============================================

app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error("Error:", err);

  if (err.message === "Not allowed by CORS") {
    res.status(403).json({ error: "CORS policy violation" });
  } else {
    res.status(500).json({
      error: "Internal server error",
      message: process.env.NODE_ENV === "development" ? err.message : undefined,
    });
  }
});

// 404 handler
app.use((req: Request, res: Response) => {
  res.status(404).json({ error: "Route not found" });
});

// ============================================
// Server Startup
// ============================================

const PORT = process.env.PORT || 3000;

httpServer.listen(PORT, () => {
  console.log(`
╔════════════════════════════════════════╗
║     TelePrompt Pro API Gateway        ║
║────────────────────────────────────────║
║  Server running on port ${PORT}          ║
║  Health: http://localhost:${PORT}/api/health
║  WebSocket: ws://localhost:${PORT}       ║
║────────────────────────────────────────║
║  Environment: ${process.env.NODE_ENV || "development"}
╚════════════════════════════════════════╝
  `);
});

// Graceful shutdown
process.on("SIGTERM", async () => {
  console.log("SIGTERM received, shutting down gracefully...");

  httpServer.close(() => {
    console.log("HTTP server closed");
  });

  await prisma.$disconnect();
  await redis.quit();

  process.exit(0);
});
