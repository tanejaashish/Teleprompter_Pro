// Centralized Error Handling and Logging Middleware

import { Request, Response, NextFunction } from "express";
import winston from "winston";

// Custom error classes
export class AppError extends Error {
  constructor(
    public message: string,
    public statusCode: number = 500,
    public isOperational: boolean = true,
    public code?: string,
  ) {
    super(message);
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }
}

export class ValidationError extends AppError {
  constructor(message: string, public details?: any) {
    super(message, 400, true, "VALIDATION_ERROR");
  }
}

export class AuthenticationError extends AppError {
  constructor(message: string = "Authentication required") {
    super(message, 401, true, "AUTH_ERROR");
  }
}

export class AuthorizationError extends AppError {
  constructor(message: string = "Insufficient permissions") {
    super(message, 403, true, "AUTHZ_ERROR");
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string = "Resource") {
    super(`${resource} not found`, 404, true, "NOT_FOUND");
  }
}

export class ConflictError extends AppError {
  constructor(message: string) {
    super(message, 409, true, "CONFLICT");
  }
}

export class RateLimitError extends AppError {
  constructor(message: string = "Too many requests") {
    super(message, 429, true, "RATE_LIMIT");
  }
}

export class ServiceUnavailableError extends AppError {
  constructor(message: string = "Service temporarily unavailable") {
    super(message, 503, true, "SERVICE_UNAVAILABLE");
  }
}

// Winston logger configuration
export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || "info",
  format: winston.format.combine(
    winston.format.timestamp({
      format: "YYYY-MM-DD HH:mm:ss",
    }),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json(),
  ),
  defaultMeta: { service: "teleprompt-api" },
  transports: [
    // Write errors to error.log
    new winston.transports.File({
      filename: process.env.LOG_FILE_PATH || "./logs/error.log",
      level: "error",
      maxsize: 10 * 1024 * 1024, // 10MB
      maxFiles: 10,
    }),
    // Write all logs to combined.log
    new winston.transports.File({
      filename: process.env.LOG_FILE_PATH?.replace("error", "combined") || "./logs/combined.log",
      maxsize: 10 * 1024 * 1024,
      maxFiles: 10,
    }),
  ],
});

// Console logging for development
if (process.env.NODE_ENV !== "production") {
  logger.add(
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple(),
      ),
    }),
  );
}

// Request logging middleware
export const requestLogger = (
  req: Request,
  res: Response,
  next: NextFunction,
): void => {
  const start = Date.now();

  res.on("finish", () => {
    const duration = Date.now() - start;
    const logData = {
      method: req.method,
      url: req.url,
      status: res.statusCode,
      duration: `${duration}ms`,
      ip: req.ip,
      userAgent: req.get("user-agent"),
      userId: (req as any).user?.id,
    };

    if (res.statusCode >= 400) {
      logger.error("HTTP Error", logData);
    } else {
      logger.info("HTTP Request", logData);
    }
  });

  next();
};

// Error handler middleware
export const errorHandler = (
  err: Error | AppError,
  req: Request,
  res: Response,
  next: NextFunction,
): void => {
  // Log the error
  logError(err, req);

  // Determine if error is operational
  const isOperational =
    err instanceof AppError ? err.isOperational : false;

  // Get status code
  const statusCode =
    err instanceof AppError ? err.statusCode : 500;

  // Get error code
  const code = err instanceof AppError ? err.code : "INTERNAL_ERROR";

  // Prepare error response
  const errorResponse: any = {
    error: {
      message: isOperational
        ? err.message
        : "An unexpected error occurred",
      code,
      status: statusCode,
    },
  };

  // Add details for validation errors
  if (err instanceof ValidationError && err.details) {
    errorResponse.error.details = err.details;
  }

  // Add stack trace in development
  if (process.env.NODE_ENV === "development") {
    errorResponse.error.stack = err.stack;
  }

  // Add request ID for tracking
  errorResponse.error.requestId = (req as any).id || "unknown";

  // Send error response
  res.status(statusCode).json(errorResponse);

  // Report critical errors to monitoring service
  if (!isOperational || statusCode >= 500) {
    reportToMonitoring(err, req);
  }
};

// Log error with context
function logError(err: Error, req: Request): void {
  const errorLog = {
    name: err.name,
    message: err.message,
    stack: err.stack,
    method: req.method,
    url: req.url,
    body: req.body,
    params: req.params,
    query: req.query,
    ip: req.ip,
    userId: (req as any).user?.id,
    timestamp: new Date().toISOString(),
  };

  logger.error("Application Error", errorLog);
}

// Report to monitoring service (Sentry, DataDog, etc.)
function reportToMonitoring(err: Error, req: Request): void {
  // TODO: Integrate with Sentry or similar
  console.error("CRITICAL ERROR:", {
    error: err.message,
    stack: err.stack,
    url: req.url,
  });

  // Sentry example:
  // Sentry.captureException(err, {
  //   extra: {
  //     url: req.url,
  //     method: req.method,
  //     userId: (req as any).user?.id,
  //   },
  // });
}

// Async error wrapper
export const asyncHandler =
  (fn: Function) =>
  (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };

// Not found handler
export const notFoundHandler = (
  req: Request,
  res: Response,
  next: NextFunction,
): void => {
  next(new NotFoundError("Route"));
};

// Unhandled rejection handler
export const setupGlobalErrorHandlers = (): void => {
  process.on("unhandledRejection", (reason: Error) => {
    logger.error("Unhandled Rejection:", {
      error: reason.message,
      stack: reason.stack,
    });
    // Don't exit in development
    if (process.env.NODE_ENV === "production") {
      process.exit(1);
    }
  });

  process.on("uncaughtException", (error: Error) => {
    logger.error("Uncaught Exception:", {
      error: error.message,
      stack: error.stack,
    });
    // Always exit on uncaught exception
    process.exit(1);
  });
};

// Health check error handler
export const healthCheckError = (service: string): ServiceUnavailableError => {
  return new ServiceUnavailableError(`${service} is not responding`);
};

// Database error handler
export const handleDatabaseError = (err: any): AppError => {
  if (err.code === "P2002") {
    // Unique constraint violation
    return new ConflictError(
      "A record with this value already exists",
    );
  }

  if (err.code === "P2025") {
    // Record not found
    return new NotFoundError("Record");
  }

  // Generic database error
  logger.error("Database error:", err);
  return new AppError("Database operation failed", 500, false);
};

// External API error handler
export const handleExternalApiError = (
  serviceName: string,
  err: any,
): AppError => {
  logger.error(`${serviceName} API error:`, err);

  if (err.response?.status === 429) {
    return new RateLimitError(
      `${serviceName} rate limit exceeded`,
    );
  }

  if (err.response?.status >= 500) {
    return new ServiceUnavailableError(
      `${serviceName} is currently unavailable`,
    );
  }

  return new AppError(`${serviceName} error: ${err.message}`, 502);
};
