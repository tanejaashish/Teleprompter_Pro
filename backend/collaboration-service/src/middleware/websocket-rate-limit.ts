// WebSocket Rate Limiting Middleware
// Prevents abuse of WebSocket connections and message flooding

import { Socket } from 'socket.io';
import Redis from 'ioredis';

interface RateLimitConfig {
  points: number; // Number of requests
  duration: number; // Time window in seconds
  blockDuration?: number; // Block duration in seconds if exceeded
}

interface RateLimitInfo {
  points: number;
  resetAt: number;
  blocked: boolean;
  blockedUntil?: number;
}

export class WebSocketRateLimiter {
  private redis: Redis;
  private config: RateLimitConfig;
  private keyPrefix: string;

  constructor(
    redis: Redis,
    config: RateLimitConfig = {
      points: 100, // 100 messages
      duration: 60, // per minute
      blockDuration: 300, // block for 5 minutes if exceeded
    },
  ) {
    this.redis = redis;
    this.config = config;
    this.keyPrefix = 'ws:ratelimit';
  }

  // Get rate limit key
  private getKey(identifier: string): string {
    return `${this.keyPrefix}:${identifier}`;
  }

  // Check if request is allowed
  async consume(identifier: string, points: number = 1): Promise<RateLimitInfo> {
    const key = this.getKey(identifier);
    const now = Date.now();

    try {
      // Check if blocked
      const blockKey = `${key}:blocked`;
      const blockedUntil = await this.redis.get(blockKey);

      if (blockedUntil && parseInt(blockedUntil) > now) {
        return {
          points: 0,
          resetAt: parseInt(blockedUntil),
          blocked: true,
          blockedUntil: parseInt(blockedUntil),
        };
      }

      // Increment counter
      const current = await this.redis.incr(key);

      if (current === 1) {
        // First request in window, set expiration
        await this.redis.expire(key, this.config.duration);
      }

      const ttl = await this.redis.ttl(key);
      const resetAt = now + ttl * 1000;

      // Check if exceeded
      if (current > this.config.points) {
        // Block the client
        if (this.config.blockDuration) {
          const blockUntil = now + this.config.blockDuration * 1000;
          await this.redis.set(blockKey, blockUntil.toString());
          await this.redis.expire(blockKey, this.config.blockDuration);

          return {
            points: 0,
            resetAt: blockUntil,
            blocked: true,
            blockedUntil: blockUntil,
          };
        }

        return {
          points: 0,
          resetAt,
          blocked: true,
        };
      }

      return {
        points: this.config.points - current,
        resetAt,
        blocked: false,
      };
    } catch (error) {
      console.error('Rate limit error:', error);
      // On error, allow the request (fail open)
      return {
        points: this.config.points,
        resetAt: now + this.config.duration * 1000,
        blocked: false,
      };
    }
  }

  // Reset rate limit for identifier
  async reset(identifier: string): Promise<void> {
    const key = this.getKey(identifier);
    const blockKey = `${key}:blocked`;
    await this.redis.del(key, blockKey);
  }

  // Get current rate limit status
  async getStatus(identifier: string): Promise<RateLimitInfo> {
    const key = this.getKey(identifier);
    const blockKey = `${key}:blocked`;
    const now = Date.now();

    try {
      const blockedUntil = await this.redis.get(blockKey);
      if (blockedUntil && parseInt(blockedUntil) > now) {
        return {
          points: 0,
          resetAt: parseInt(blockedUntil),
          blocked: true,
          blockedUntil: parseInt(blockedUntil),
        };
      }

      const current = await this.redis.get(key);
      const ttl = await this.redis.ttl(key);

      if (!current) {
        return {
          points: this.config.points,
          resetAt: now + this.config.duration * 1000,
          blocked: false,
        };
      }

      const remaining = this.config.points - parseInt(current);
      const resetAt = now + ttl * 1000;

      return {
        points: Math.max(0, remaining),
        resetAt,
        blocked: remaining <= 0,
      };
    } catch (error) {
      console.error('Get status error:', error);
      return {
        points: this.config.points,
        resetAt: now + this.config.duration * 1000,
        blocked: false,
      };
    }
  }
}

// WebSocket Rate Limiting Middleware Factory
export const createWebSocketRateLimitMiddleware = (
  redis: Redis,
  config?: RateLimitConfig,
) => {
  const limiter = new WebSocketRateLimiter(redis, config);

  return (socket: Socket, next: (err?: Error) => void) => {
    // Get identifier (user ID or IP address)
    const userId = (socket as any).user?.id;
    const identifier = userId || socket.handshake.address;

    // Check rate limit on connection
    limiter
      .consume(identifier, 1)
      .then((info) => {
        if (info.blocked) {
          const error = new Error('Rate limit exceeded');
          (error as any).data = {
            rateLimitExceeded: true,
            resetAt: info.resetAt,
            blockedUntil: info.blockedUntil,
          };
          return next(error);
        }

        // Attach rate limiter to socket
        (socket as any).rateLimiter = limiter;
        (socket as any).rateLimitIdentifier = identifier;

        next();
      })
      .catch((error) => {
        console.error('Rate limit middleware error:', error);
        // On error, allow connection
        next();
      });
  };
};

// Message rate limiting
export const rateLimitMessage = async (
  socket: Socket,
  points: number = 1,
): Promise<boolean> => {
  const limiter = (socket as any).rateLimiter as WebSocketRateLimiter;
  const identifier = (socket as any).rateLimitIdentifier as string;

  if (!limiter || !identifier) {
    return true; // No rate limiter configured, allow message
  }

  const info = await limiter.consume(identifier, points);

  if (info.blocked) {
    // Emit rate limit error
    socket.emit('error', {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many messages',
      resetAt: info.resetAt,
      blockedUntil: info.blockedUntil,
    });

    return false;
  }

  return true;
};

// Per-event rate limiting
export class EventRateLimiter {
  private limiters: Map<string, WebSocketRateLimiter>;
  private redis: Redis;

  constructor(redis: Redis) {
    this.redis = redis;
    this.limiters = new Map();
  }

  // Configure rate limit for specific event
  configureEvent(
    eventName: string,
    config: RateLimitConfig,
  ): void {
    this.limiters.set(
      eventName,
      new WebSocketRateLimiter(this.redis, config),
    );
  }

  // Check rate limit for event
  async checkEvent(
    socket: Socket,
    eventName: string,
    points: number = 1,
  ): Promise<boolean> {
    const limiter = this.limiters.get(eventName);

    if (!limiter) {
      return true; // No rate limit configured for this event
    }

    const userId = (socket as any).user?.id;
    const identifier = `${userId || socket.handshake.address}:${eventName}`;

    const info = await limiter.consume(identifier, points);

    if (info.blocked) {
      socket.emit('error', {
        code: 'RATE_LIMIT_EXCEEDED',
        message: `Too many ${eventName} events`,
        event: eventName,
        resetAt: info.resetAt,
        blockedUntil: info.blockedUntil,
      });

      return false;
    }

    return true;
  }
}

// Usage example:
/*
import { Server } from 'socket.io';
import Redis from 'ioredis';

const io = new Server(server);
const redis = new Redis(process.env.REDIS_URL);

// Global connection rate limiting
io.use(createWebSocketRateLimitMiddleware(redis, {
  points: 100,    // 100 messages
  duration: 60,   // per minute
  blockDuration: 300, // block for 5 minutes
}));

// Per-event rate limiting
const eventLimiter = new EventRateLimiter(redis);

// Configure stricter limits for expensive operations
eventLimiter.configureEvent('operation', {
  points: 50,
  duration: 60,
  blockDuration: 300,
});

eventLimiter.configureEvent('cursor_update', {
  points: 200,  // Allow more frequent cursor updates
  duration: 60,
});

// Apply in event handlers
io.on('connection', (socket) => {
  socket.on('operation', async (data) => {
    // Check rate limit
    const allowed = await eventLimiter.checkEvent(socket, 'operation');
    if (!allowed) return;

    // Process operation
    handleOperation(data);
  });

  socket.on('cursor_update', async (data) => {
    const allowed = await eventLimiter.checkEvent(socket, 'cursor_update');
    if (!allowed) return;

    handleCursorUpdate(data);
  });
});
*/

// Cleanup utility
export const cleanupRateLimits = async (
  redis: Redis,
  pattern: string = 'ws:ratelimit:*',
): Promise<number> => {
  try {
    const keys = await redis.keys(pattern);
    if (keys.length > 0) {
      await redis.del(...keys);
    }
    return keys.length;
  } catch (error) {
    console.error('Cleanup rate limits error:', error);
    return 0;
  }
};
