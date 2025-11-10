// Security Audit Middleware
// Tracks and logs security-relevant events for compliance and monitoring

import { Request, Response, NextFunction } from 'express';
import { PrismaClient } from '@prisma/client';
import { createHash } from 'crypto';

const prisma = new PrismaClient();

// Security event types
export enum SecurityEventType {
  // Authentication events
  LOGIN_SUCCESS = 'login_success',
  LOGIN_FAILURE = 'login_failure',
  LOGOUT = 'logout',
  PASSWORD_CHANGE = 'password_change',
  PASSWORD_RESET_REQUEST = 'password_reset_request',
  PASSWORD_RESET_COMPLETE = 'password_reset_complete',
  EMAIL_VERIFICATION = 'email_verification',

  // Authorization events
  ACCESS_DENIED = 'access_denied',
  PERMISSION_ELEVATION = 'permission_elevation',

  // Account events
  ACCOUNT_CREATED = 'account_created',
  ACCOUNT_DELETED = 'account_deleted',
  ACCOUNT_SUSPENDED = 'account_suspended',
  ACCOUNT_REACTIVATED = 'account_reactivated',

  // Data access events
  SENSITIVE_DATA_ACCESS = 'sensitive_data_access',
  BULK_DATA_EXPORT = 'bulk_data_export',
  DATA_DELETION = 'data_deletion',

  // Security events
  SUSPICIOUS_ACTIVITY = 'suspicious_activity',
  RATE_LIMIT_EXCEEDED = 'rate_limit_exceeded',
  INVALID_TOKEN = 'invalid_token',
  SQL_INJECTION_ATTEMPT = 'sql_injection_attempt',
  XSS_ATTEMPT = 'xss_attempt',
  CSRF_FAILURE = 'csrf_failure',

  // Admin events
  ADMIN_ACTION = 'admin_action',
  CONFIG_CHANGE = 'config_change',
  USER_IMPERSONATION = 'user_impersonation',
}

export interface AuditLogEntry {
  userId?: string;
  userEmail?: string;
  action: string;
  resource: string;
  resourceId?: string;
  ipAddress?: string;
  userAgent?: string;
  method?: string;
  path?: string;
  statusCode?: number;
  success: boolean;
  errorMessage?: string;
  metadata?: any;
}

// Log security event
export const logSecurityEvent = async (
  eventType: SecurityEventType,
  entry: AuditLogEntry,
): Promise<void> => {
  try {
    await prisma.auditLog.create({
      data: {
        userId: entry.userId,
        userEmail: entry.userEmail,
        action: eventType,
        resource: entry.resource,
        resourceId: entry.resourceId,
        ipAddress: entry.ipAddress,
        userAgent: entry.userAgent,
        method: entry.method,
        path: entry.path,
        statusCode: entry.statusCode,
        success: entry.success,
        errorMessage: entry.errorMessage,
        metadata: entry.metadata || {},
      },
    });

    // Emit to monitoring service (Sentry, DataDog, etc.)
    if (!entry.success) {
      console.warn(`Security event: ${eventType}`, {
        userId: entry.userId,
        action: eventType,
        resource: entry.resource,
        success: entry.success,
      });
    }
  } catch (error) {
    console.error('Failed to log security event:', error);
  }
};

// Audit middleware
export const auditMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const startTime = Date.now();

  // Store original send method
  const originalSend = res.send.bind(res);

  // Override send to log after response
  res.send = function (data: any) {
    const duration = Date.now() - startTime;

    // Determine if this should be audited
    const shouldAudit =
      req.method !== 'GET' || // Audit all non-GET requests
      res.statusCode >= 400 || // Audit all errors
      req.path.includes('/admin') || // Audit admin actions
      req.path.includes('/api/auth'); // Audit auth actions

    if (shouldAudit) {
      const userId = (req as any).user?.id;
      const userEmail = (req as any).user?.email;

      const entry: AuditLogEntry = {
        userId,
        userEmail,
        action: getActionFromMethod(req.method),
        resource: getResourceFromPath(req.path),
        resourceId: req.params.id,
        ipAddress: getClientIp(req),
        userAgent: req.get('user-agent'),
        method: req.method,
        path: req.path,
        statusCode: res.statusCode,
        success: res.statusCode >= 200 && res.statusCode < 400,
        metadata: {
          duration,
          query: req.query,
          body: sanitizeBody(req.body),
        },
      };

      // Determine event type
      const eventType = determineEventType(req, res);

      logSecurityEvent(eventType, entry).catch((err) =>
        console.error('Audit log error:', err),
      );
    }

    return originalSend(data);
  };

  next();
};

// Security checks middleware
export const securityChecks = (req: Request, res: Response, next: NextFunction) => {
  const checks: Array<{ name: string; check: () => boolean }> = [
    {
      name: 'SQL Injection',
      check: () => detectSQLInjection(req),
    },
    {
      name: 'XSS',
      check: () => detectXSS(req),
    },
    {
      name: 'Path Traversal',
      check: () => detectPathTraversal(req),
    },
    {
      name: 'Command Injection',
      check: () => detectCommandInjection(req),
    },
  ];

  for (const { name, check } of checks) {
    if (check()) {
      const userId = (req as any).user?.id;

      logSecurityEvent(
        name === 'SQL Injection'
          ? SecurityEventType.SQL_INJECTION_ATTEMPT
          : SecurityEventType.XSS_ATTEMPT,
        {
          userId,
          action: 'security_violation',
          resource: 'request',
          ipAddress: getClientIp(req),
          userAgent: req.get('user-agent'),
          method: req.method,
          path: req.path,
          success: false,
          errorMessage: `${name} attempt detected`,
          metadata: {
            query: req.query,
            body: req.body,
          },
        },
      );

      return res.status(400).json({
        error: {
          message: 'Invalid request',
          code: 'SECURITY_VIOLATION',
        },
      });
    }
  }

  next();
};

// Helper functions
function getActionFromMethod(method: string): string {
  const actionMap: Record<string, string> = {
    GET: 'view',
    POST: 'create',
    PUT: 'update',
    PATCH: 'update',
    DELETE: 'delete',
  };

  return actionMap[method] || method.toLowerCase();
}

function getResourceFromPath(path: string): string {
  // Extract resource from path (e.g., /api/scripts/123 -> scripts)
  const match = path.match(/\/api\/([^\/]+)/);
  return match ? match[1] : 'unknown';
}

function getClientIp(req: Request): string {
  return (
    (req.headers['x-forwarded-for'] as string)?.split(',')[0] ||
    req.socket.remoteAddress ||
    'unknown'
  );
}

function sanitizeBody(body: any): any {
  if (!body || typeof body !== 'object') return body;

  const sensitiveFields = ['password', 'token', 'secret', 'apiKey', 'creditCard'];
  const sanitized = { ...body };

  for (const field of sensitiveFields) {
    if (field in sanitized) {
      sanitized[field] = '[REDACTED]';
    }
  }

  return sanitized;
}

function determineEventType(req: Request, res: Response): SecurityEventType {
  // Authentication events
  if (req.path.includes('/auth/signin') || req.path.includes('/auth/login')) {
    return res.statusCode < 400
      ? SecurityEventType.LOGIN_SUCCESS
      : SecurityEventType.LOGIN_FAILURE;
  }

  if (req.path.includes('/auth/signout') || req.path.includes('/auth/logout')) {
    return SecurityEventType.LOGOUT;
  }

  if (req.path.includes('/auth/signup') || req.path.includes('/auth/register')) {
    return SecurityEventType.ACCOUNT_CREATED;
  }

  if (req.path.includes('/password/reset')) {
    if (req.method === 'POST') {
      return SecurityEventType.PASSWORD_RESET_REQUEST;
    } else if (req.method === 'PUT') {
      return SecurityEventType.PASSWORD_RESET_COMPLETE;
    }
  }

  // Authorization events
  if (res.statusCode === 403) {
    return SecurityEventType.ACCESS_DENIED;
  }

  // Rate limiting
  if (res.statusCode === 429) {
    return SecurityEventType.RATE_LIMIT_EXCEEDED;
  }

  // Default
  return SecurityEventType.SUSPICIOUS_ACTIVITY;
}

// Security threat detection
function detectSQLInjection(req: Request): boolean {
  const sqlPatterns = [
    /(\bunion\b.*\bselect\b)/i,
    /(\bor\b\s*\d+\s*=\s*\d+)/i,
    /(\bdrop\b.*\btable\b)/i,
    /(\binsert\b.*\binto\b)/i,
    /(\bdelete\b.*\bfrom\b)/i,
    /(\bupdate\b.*\bset\b)/i,
    /(;.*--)/,
    /(\/\*.*\*\/)/,
  ];

  const checkString = JSON.stringify(req.query) + JSON.stringify(req.body);

  return sqlPatterns.some((pattern) => pattern.test(checkString));
}

function detectXSS(req: Request): boolean {
  const xssPatterns = [
    /<script[^>]*>.*<\/script>/gi,
    /javascript:/gi,
    /on\w+\s*=\s*["'][^"']*["']/gi,
    /<iframe[^>]*>/gi,
    /<object[^>]*>/gi,
    /<embed[^>]*>/gi,
  ];

  const checkString = JSON.stringify(req.query) + JSON.stringify(req.body);

  return xssPatterns.some((pattern) => pattern.test(checkString));
}

function detectPathTraversal(req: Request): boolean {
  const pathTraversalPatterns = [
    /\.\.\//g,
    /\.\.\\/g,
    /%2e%2e%2f/gi,
    /%2e%2e\//gi,
    /\.\.%2f/gi,
  ];

  const checkString = req.path + JSON.stringify(req.query);

  return pathTraversalPatterns.some((pattern) => pattern.test(checkString));
}

function detectCommandInjection(req: Request): boolean {
  const commandPatterns = [
    /[;&|`$()]/,
    /\bwget\b|\bcurl\b/i,
    /\bnc\b|\bnetcat\b/i,
    /\bsh\b|\bbash\b|\bzsh\b/i,
  ];

  const checkString = JSON.stringify(req.query) + JSON.stringify(req.body);

  return commandPatterns.some((pattern) => pattern.test(checkString));
}

// Get audit logs for user
export const getUserAuditLogs = async (
  userId: string,
  options: {
    limit?: number;
    offset?: number;
    startDate?: Date;
    endDate?: Date;
    action?: string;
  } = {},
): Promise<any[]> => {
  const where: any = { userId };

  if (options.startDate || options.endDate) {
    where.createdAt = {};
    if (options.startDate) where.createdAt.gte = options.startDate;
    if (options.endDate) where.createdAt.lte = options.endDate;
  }

  if (options.action) {
    where.action = options.action;
  }

  return prisma.auditLog.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    take: options.limit || 100,
    skip: options.offset || 0,
  });
};

// Get security alerts
export const getSecurityAlerts = async (
  timeWindow: number = 24, // hours
): Promise<any[]> => {
  const since = new Date(Date.now() - timeWindow * 60 * 60 * 1000);

  return prisma.auditLog.findMany({
    where: {
      success: false,
      createdAt: { gte: since },
      action: {
        in: [
          SecurityEventType.SQL_INJECTION_ATTEMPT,
          SecurityEventType.XSS_ATTEMPT,
          SecurityEventType.SUSPICIOUS_ACTIVITY,
          SecurityEventType.RATE_LIMIT_EXCEEDED,
        ],
      },
    },
    orderBy: { createdAt: 'desc' },
    take: 100,
  });
};

// Detect anomalous behavior
export const detectAnomalies = async (userId: string): Promise<boolean> => {
  const recentLogs = await prisma.auditLog.findMany({
    where: {
      userId,
      createdAt: {
        gte: new Date(Date.now() - 15 * 60 * 1000), // Last 15 minutes
      },
    },
  });

  // Check for suspicious patterns
  const failedLogins = recentLogs.filter(
    (log) => log.action === SecurityEventType.LOGIN_FAILURE,
  ).length;

  const rapidRequests = recentLogs.length > 100; // More than 100 requests in 15 min

  const multipleIPs = new Set(recentLogs.map((log) => log.ipAddress)).size > 3;

  return failedLogins > 5 || rapidRequests || multipleIPs;
};
