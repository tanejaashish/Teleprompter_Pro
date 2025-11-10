// Input Validation Middleware
// Comprehensive validation for API requests using express-validator

import { body, param, query, validationResult } from "express-validator";
import { Request, Response, NextFunction } from "express";

// Validation error handler
export const handleValidationErrors = (
  req: Request,
  res: Response,
  next: NextFunction,
): void => {
  const errors = validationResult(req);

  if (!errors.isEmpty()) {
    res.status(400).json({
      error: "Validation failed",
      details: errors.array().map((err) => ({
        field: (err as any).path,
        message: err.msg,
        value: (err as any).value,
      })),
    });
    return;
  }

  next();
};

// Authentication validators
export const signupValidation = [
  body("email")
    .isEmail()
    .normalizeEmail()
    .withMessage("Valid email is required"),
  body("password")
    .isLength({ min: 8 })
    .withMessage("Password must be at least 8 characters")
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage(
      "Password must contain at least one uppercase letter, one lowercase letter, and one number",
    ),
  body("displayName")
    .optional()
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage("Display name must be between 2 and 50 characters"),
  handleValidationErrors,
];

export const signinValidation = [
  body("email").isEmail().withMessage("Valid email is required"),
  body("password").notEmpty().withMessage("Password is required"),
  body("deviceId").optional().isString(),
  body("deviceName").optional().isString(),
  handleValidationErrors,
];

// Script validators
export const createScriptValidation = [
  body("title")
    .trim()
    .notEmpty()
    .withMessage("Title is required")
    .isLength({ max: 200 })
    .withMessage("Title must be less than 200 characters"),
  body("content")
    .notEmpty()
    .withMessage("Content is required")
    .isLength({ max: 1000000 })
    .withMessage("Content is too large (max 1MB)"),
  body("richContent").optional().isString(),
  body("category")
    .optional()
    .isIn([
      "presentation",
      "video",
      "speech",
      "tutorial",
      "news",
      "other",
    ])
    .withMessage("Invalid category"),
  body("tags")
    .optional()
    .isArray()
    .withMessage("Tags must be an array"),
  body("tags.*")
    .optional()
    .isString()
    .trim()
    .isLength({ max: 50 }),
  body("settings").optional().isObject(),
  handleValidationErrors,
];

export const updateScriptValidation = [
  param("id").isString().withMessage("Script ID is required"),
  body("title")
    .optional()
    .trim()
    .notEmpty()
    .isLength({ max: 200 })
    .withMessage("Title must be less than 200 characters"),
  body("content")
    .optional()
    .isLength({ max: 1000000 })
    .withMessage("Content is too large"),
  body("richContent").optional().isString(),
  body("category").optional().isString(),
  body("tags").optional().isArray(),
  body("settings").optional().isObject(),
  handleValidationErrors,
];

// Recording validators
export const createRecordingValidation = [
  body("title")
    .trim()
    .notEmpty()
    .withMessage("Title is required")
    .isLength({ max: 200 }),
  body("scriptId").optional().isString(),
  body("duration")
    .isInt({ min: 1 })
    .withMessage("Duration must be a positive integer"),
  body("quality")
    .optional()
    .isIn(["720p", "1080p", "4K"])
    .withMessage("Invalid quality"),
  body("format")
    .optional()
    .isIn(["mp4", "mov", "webm"])
    .withMessage("Invalid format"),
  handleValidationErrors,
];

// Payment validators
export const createCheckoutSessionValidation = [
  body("plan")
    .isIn(["advanced", "pro", "team"])
    .withMessage("Invalid plan"),
  body("interval")
    .isIn(["monthly", "yearly"])
    .withMessage("Invalid interval"),
  body("successUrl")
    .isURL()
    .withMessage("Valid success URL is required"),
  body("cancelUrl")
    .isURL()
    .withMessage("Valid cancel URL is required"),
  body("quantity")
    .optional()
    .isInt({ min: 1, max: 50 })
    .withMessage("Quantity must be between 1 and 50"),
  body("couponCode").optional().isString().trim(),
  body("trialDays")
    .optional()
    .isInt({ min: 0, max: 30 })
    .withMessage("Trial days must be between 0 and 30"),
  handleValidationErrors,
];

// Collaboration validators
export const inviteCollaboratorValidation = [
  param("scriptId")
    .isString()
    .withMessage("Script ID is required"),
  body("email")
    .isEmail()
    .normalizeEmail()
    .withMessage("Valid email is required"),
  body("role")
    .isIn(["viewer", "editor"])
    .withMessage("Role must be viewer or editor"),
  handleValidationErrors,
];

// AI Service validators
export const generateScriptValidation = [
  body("topic")
    .trim()
    .notEmpty()
    .withMessage("Topic is required")
    .isLength({ min: 5, max: 200 })
    .withMessage("Topic must be between 5 and 200 characters"),
  body("style")
    .isIn([
      "professional",
      "casual",
      "educational",
      "persuasive",
      "storytelling",
    ])
    .withMessage("Invalid style"),
  body("duration")
    .isInt({ min: 30, max: 3600 })
    .withMessage("Duration must be between 30 seconds and 1 hour"),
  body("audience")
    .isIn(["general", "technical", "executives", "students", "customers"])
    .withMessage("Invalid audience"),
  body("tone")
    .isIn(["formal", "informal", "friendly", "authoritative"])
    .withMessage("Invalid tone"),
  body("keywords")
    .optional()
    .isArray()
    .withMessage("Keywords must be an array"),
  body("context")
    .optional()
    .isLength({ max: 1000 })
    .withMessage("Context must be less than 1000 characters"),
  handleValidationErrors,
];

// File upload validators
export const uploadFileValidation = (
  allowedMimeTypes: string[],
  maxSizeMB: number,
) => {
  return [
    (req: Request, res: Response, next: NextFunction) => {
      if (!req.file) {
        res.status(400).json({ error: "File is required" });
        return;
      }

      // Check MIME type
      if (!allowedMimeTypes.includes(req.file.mimetype)) {
        res.status(400).json({
          error: "Invalid file type",
          allowed: allowedMimeTypes,
        });
        return;
      }

      // Check file size
      const maxSize = maxSizeMB * 1024 * 1024;
      if (req.file.size > maxSize) {
        res.status(400).json({
          error: `File too large. Maximum size is ${maxSizeMB}MB`,
        });
        return;
      }

      next();
    },
  ];
};

// Query parameter validators
export const paginationValidation = [
  query("page")
    .optional()
    .isInt({ min: 1 })
    .withMessage("Page must be a positive integer"),
  query("limit")
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage("Limit must be between 1 and 100"),
  handleValidationErrors,
];

export const dateRangeValidation = [
  query("startDate")
    .optional()
    .isISO8601()
    .withMessage("Invalid start date format"),
  query("endDate")
    .optional()
    .isISO8601()
    .withMessage("Invalid end date format"),
  handleValidationErrors,
];

// Sanitization helpers
export const sanitizeHtml = (text: string): string => {
  // Basic HTML sanitization (use DOMPurify for production)
  return text
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, "")
    .replace(/<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi, "")
    .replace(/on\w+="[^"]*"/g, "");
};

export const sanitizeInput = (input: any): any => {
  if (typeof input === "string") {
    return input.trim();
  }
  if (Array.isArray(input)) {
    return input.map(sanitizeInput);
  }
  if (typeof input === "object" && input !== null) {
    const sanitized: any = {};
    for (const [key, value] of Object.entries(input)) {
      sanitized[key] = sanitizeInput(value);
    }
    return sanitized;
  }
  return input;
};

// Custom validators
export const isValidScriptId = (value: string): boolean => {
  return /^[a-zA-Z0-9_-]+$/.test(value);
};

export const isValidUrl = (value: string): boolean => {
  try {
    new URL(value);
    return true;
  } catch {
    return false;
  }
};

export const isValidJson = (value: string): boolean => {
  try {
    JSON.parse(value);
    return true;
  } catch {
    return false;
  }
};
