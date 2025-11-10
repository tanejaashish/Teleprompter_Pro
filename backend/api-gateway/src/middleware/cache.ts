// Redis Caching Middleware
// Implements intelligent caching for API responses

import { Request, Response, NextFunction } from 'express';
import Redis from 'ioredis';
import { createHash } from 'crypto';

// Redis client singleton
let redisClient: Redis | null = null;

export const getRedisClient = (): Redis => {
  if (!redisClient) {
    redisClient = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
      maxRetriesPerRequest: 3,
      enableReadyCheck: true,
      retryStrategy: (times) => {
        const delay = Math.min(times * 50, 2000);
        return delay;
      },
    });

    redisClient.on('error', (err) => {
      console.error('Redis client error:', err);
    });

    redisClient.on('connect', () => {
      console.log('Redis client connected');
    });
  }

  return redisClient;
};

// Cache configuration
export interface CacheOptions {
  ttl?: number; // Time to live in seconds
  key?: string; // Custom cache key
  keyPrefix?: string; // Prefix for cache keys
  vary?: string[]; // Header names to include in cache key
  condition?: (req: Request, res: Response) => boolean; // Cache condition
  invalidateOn?: string[]; // Actions that invalidate this cache
  tags?: string[]; // Cache tags for group invalidation
}

// Default cache TTL by route pattern
const DEFAULT_TTLS: Record<string, number> = {
  '/api/scripts': 300, // 5 minutes
  '/api/recordings': 300, // 5 minutes
  '/api/user/profile': 600, // 10 minutes
  '/api/analytics': 1800, // 30 minutes
  '/api/templates': 3600, // 1 hour
};

// Generate cache key
function generateCacheKey(req: Request, options: CacheOptions): string {
  const parts: string[] = [
    options.keyPrefix || 'api',
    req.method,
    req.path,
  ];

  // Include query parameters
  if (Object.keys(req.query).length > 0) {
    const sortedQuery = Object.keys(req.query)
      .sort()
      .map((key) => `${key}=${req.query[key]}`)
      .join('&');
    parts.push(sortedQuery);
  }

  // Include specific headers (e.g., Accept-Language)
  if (options.vary && options.vary.length > 0) {
    for (const header of options.vary) {
      const value = req.get(header);
      if (value) {
        parts.push(`${header}:${value}`);
      }
    }
  }

  // Include user ID for user-specific caching
  if ((req as any).user?.id) {
    parts.push(`user:${(req as any).user.id}`);
  }

  const keyString = parts.join(':');

  // Use custom key if provided, otherwise hash the generated key
  if (options.key) {
    return options.key;
  }

  // Hash long keys
  if (keyString.length > 200) {
    const hash = createHash('md5').update(keyString).digest('hex');
    return `${options.keyPrefix || 'api'}:hash:${hash}`;
  }

  return keyString;
}

// Get TTL for route
function getTTL(req: Request, options: CacheOptions): number {
  if (options.ttl !== undefined) {
    return options.ttl;
  }

  // Check default TTLs by route
  for (const [pattern, ttl] of Object.entries(DEFAULT_TTLS)) {
    if (req.path.startsWith(pattern)) {
      return ttl;
    }
  }

  // Default TTL
  return 60; // 1 minute
}

// Cache middleware
export const cache = (options: CacheOptions = {}) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    // Only cache GET requests
    if (req.method !== 'GET') {
      return next();
    }

    // Check if caching is enabled
    if (process.env.CACHE_ENABLED === 'false') {
      return next();
    }

    try {
      const redis = getRedisClient();
      const cacheKey = generateCacheKey(req, options);
      const ttl = getTTL(req, options);

      // Try to get from cache
      const cachedData = await redis.get(cacheKey);

      if (cachedData) {
        // Parse cached response
        const cached = JSON.parse(cachedData);

        // Set cache headers
        res.setHeader('X-Cache', 'HIT');
        res.setHeader('X-Cache-Key', cacheKey);
        res.setHeader('Cache-Control', `max-age=${ttl}`);

        // Send cached response
        return res.status(cached.statusCode || 200).json(cached.data);
      }

      // Cache miss
      res.setHeader('X-Cache', 'MISS');
      res.setHeader('X-Cache-Key', cacheKey);

      // Store original json method
      const originalJson = res.json.bind(res);

      // Override json method to cache response
      res.json = function (data: any) {
        // Check cache condition
        if (options.condition && !options.condition(req, res)) {
          return originalJson(data);
        }

        // Only cache successful responses
        if (res.statusCode >= 200 && res.statusCode < 300) {
          const cacheData = {
            statusCode: res.statusCode,
            data,
            cachedAt: new Date().toISOString(),
          };

          // Store in cache asynchronously
          redis
            .setex(cacheKey, ttl, JSON.stringify(cacheData))
            .catch((err) => console.error('Cache set error:', err));

          // Store cache tags for group invalidation
          if (options.tags && options.tags.length > 0) {
            for (const tag of options.tags) {
              redis
                .sadd(`cache:tag:${tag}`, cacheKey)
                .catch((err) => console.error('Cache tag error:', err));
            }
          }
        }

        return originalJson(data);
      };

      next();
    } catch (error) {
      console.error('Cache middleware error:', error);
      // On error, continue without caching
      next();
    }
  };
};

// Cache invalidation
export const invalidateCache = async (
  pattern: string | string[],
): Promise<void> => {
  try {
    const redis = getRedisClient();
    const patterns = Array.isArray(pattern) ? pattern : [pattern];

    for (const p of patterns) {
      const keys = await redis.keys(p);
      if (keys.length > 0) {
        await redis.del(...keys);
      }
    }
  } catch (error) {
    console.error('Cache invalidation error:', error);
  }
};

// Invalidate by tag
export const invalidateCacheByTag = async (tag: string): Promise<void> => {
  try {
    const redis = getRedisClient();
    const keys = await redis.smembers(`cache:tag:${tag}`);

    if (keys.length > 0) {
      await redis.del(...keys);
      await redis.del(`cache:tag:${tag}`);
    }
  } catch (error) {
    console.error('Cache tag invalidation error:', error);
  }
};

// Clear all cache
export const clearAllCache = async (): Promise<void> => {
  try {
    const redis = getRedisClient();
    const keys = await redis.keys('api:*');

    if (keys.length > 0) {
      await redis.del(...keys);
    }
  } catch (error) {
    console.error('Clear all cache error:', error);
  }
};

// Cache statistics
export const getCacheStats = async (): Promise<{
  keys: number;
  memory: string;
  hitRate?: number;
}> => {
  try {
    const redis = getRedisClient();
    const keys = await redis.keys('api:*');
    const info = await redis.info('memory');

    const memoryMatch = info.match(/used_memory_human:(\S+)/);
    const memory = memoryMatch ? memoryMatch[1] : 'unknown';

    return {
      keys: keys.length,
      memory,
    };
  } catch (error) {
    console.error('Cache stats error:', error);
    return {
      keys: 0,
      memory: 'error',
    };
  }
};

// Middleware to invalidate cache on mutations
export const invalidateOnMutation = (patterns: string | string[]) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    // Store original send method
    const originalSend = res.send.bind(res);

    // Override send to invalidate after successful response
    res.send = function (data: any) {
      // Only invalidate on successful mutations
      if (res.statusCode >= 200 && res.statusCode < 300) {
        invalidateCache(patterns).catch((err) =>
          console.error('Invalidation error:', err),
        );
      }

      return originalSend(data);
    };

    next();
  };
};

// Cache warming - preload commonly accessed data
export const warmCache = async (routes: Array<{
  path: string;
  key: string;
  ttl: number;
  data: any;
}>): Promise<void> => {
  try {
    const redis = getRedisClient();

    for (const route of routes) {
      const cacheData = {
        statusCode: 200,
        data: route.data,
        cachedAt: new Date().toISOString(),
      };

      await redis.setex(route.key, route.ttl, JSON.stringify(cacheData));
    }

    console.log(`Warmed cache for ${routes.length} routes`);
  } catch (error) {
    console.error('Cache warming error:', error);
  }
};

// Example usage in routes:
/*
// Simple caching
app.get('/api/scripts',
  cache({ ttl: 300, tags: ['scripts'] }),
  scriptsController.getAll
);

// User-specific caching with vary headers
app.get('/api/user/profile',
  cache({
    ttl: 600,
    vary: ['Accept-Language'],
    tags: ['user-profile']
  }),
  userController.getProfile
);

// Conditional caching
app.get('/api/analytics',
  cache({
    ttl: 1800,
    condition: (req, res) => !req.query.realtime,
    tags: ['analytics']
  }),
  analyticsController.get
);

// Invalidate on mutation
app.post('/api/scripts',
  invalidateOnMutation(['api:GET:/api/scripts*', 'cache:tag:scripts']),
  scriptsController.create
);

app.put('/api/scripts/:id',
  invalidateOnMutation(['api:GET:/api/scripts*', 'cache:tag:scripts']),
  scriptsController.update
);
*/
