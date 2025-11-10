// Swagger/OpenAPI Configuration
// Comprehensive API documentation for TelePrompt Pro

import swaggerJsdoc from 'swagger-jsdoc';
import swaggerUi from 'swagger-ui-express';
import { Express } from 'express';

const options: swaggerJsdoc.Options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'TelePrompt Pro API',
      version: '1.0.0',
      description: 'Complete API documentation for TelePrompt Pro - Professional Teleprompter Application',
      contact: {
        name: 'TelePrompt Pro Support',
        email: 'support@teleprompter.pro',
        url: 'https://teleprompter.pro/support',
      },
      license: {
        name: 'Proprietary',
        url: 'https://teleprompter.pro/license',
      },
    },
    servers: [
      {
        url: 'https://api.teleprompter.pro',
        description: 'Production server',
      },
      {
        url: 'https://staging-api.teleprompter.pro',
        description: 'Staging server',
      },
      {
        url: 'http://localhost:3000',
        description: 'Development server',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: 'Enter your JWT token',
        },
        apiKey: {
          type: 'apiKey',
          in: 'header',
          name: 'X-API-Key',
          description: 'API key for programmatic access',
        },
      },
      schemas: {
        // User schemas
        User: {
          type: 'object',
          properties: {
            id: { type: 'string', example: 'user_123' },
            email: { type: 'string', format: 'email', example: 'user@example.com' },
            displayName: { type: 'string', example: 'John Doe' },
            photoUrl: { type: 'string', format: 'uri', example: 'https://example.com/photo.jpg' },
            emailVerified: { type: 'boolean', example: true },
            createdAt: { type: 'string', format: 'date-time' },
            updatedAt: { type: 'string', format: 'date-time' },
          },
        },

        // Script schemas
        Script: {
          type: 'object',
          properties: {
            id: { type: 'string', example: 'script_123' },
            userId: { type: 'string', example: 'user_123' },
            title: { type: 'string', example: 'My Presentation' },
            content: { type: 'string', example: 'This is the script content...' },
            richContent: { type: 'string', nullable: true },
            wordCount: { type: 'integer', example: 250 },
            characterCount: { type: 'integer', example: 1500 },
            estimatedDuration: { type: 'integer', example: 120, description: 'Duration in seconds' },
            category: { type: 'string', example: 'presentation' },
            tags: { type: 'array', items: { type: 'string' }, example: ['business', 'meeting'] },
            isPublic: { type: 'boolean', example: false },
            isTemplate: { type: 'boolean', example: false },
            isArchived: { type: 'boolean', example: false },
            createdAt: { type: 'string', format: 'date-time' },
            updatedAt: { type: 'string', format: 'date-time' },
          },
        },

        // Recording schemas
        Recording: {
          type: 'object',
          properties: {
            id: { type: 'string', example: 'recording_123' },
            userId: { type: 'string', example: 'user_123' },
            scriptId: { type: 'string', nullable: true, example: 'script_123' },
            title: { type: 'string', example: 'My Recording' },
            duration: { type: 'integer', example: 300, description: 'Duration in seconds' },
            fileSize: { type: 'integer', example: 52428800, description: 'Size in bytes' },
            cloudUrl: { type: 'string', format: 'uri', example: 'https://cdn.example.com/recording.mp4' },
            thumbnailUrl: { type: 'string', format: 'uri', nullable: true },
            quality: { type: 'string', enum: ['720p', '1080p', '4K'], example: '1080p' },
            format: { type: 'string', enum: ['mp4', 'mov', 'webm'], example: 'mp4' },
            status: { type: 'string', enum: ['recording', 'processing', 'completed', 'failed'], example: 'completed' },
            createdAt: { type: 'string', format: 'date-time' },
          },
        },

        // Subscription schemas
        Subscription: {
          type: 'object',
          properties: {
            id: { type: 'string', example: 'sub_123' },
            userId: { type: 'string', example: 'user_123' },
            tier: { type: 'string', enum: ['free', 'creator', 'professional', 'enterprise'], example: 'professional' },
            status: { type: 'string', enum: ['active', 'cancelled', 'expired', 'suspended'], example: 'active' },
            features: { type: 'object' },
            usage: { type: 'object' },
            limits: { type: 'object' },
            startDate: { type: 'string', format: 'date-time' },
            endDate: { type: 'string', format: 'date-time', nullable: true },
            createdAt: { type: 'string', format: 'date-time' },
          },
        },

        // Error schemas
        Error: {
          type: 'object',
          properties: {
            error: {
              type: 'object',
              properties: {
                message: { type: 'string', example: 'Resource not found' },
                code: { type: 'string', example: 'NOT_FOUND' },
                status: { type: 'integer', example: 404 },
                details: { type: 'object', nullable: true },
              },
            },
          },
        },
      },
      responses: {
        UnauthorizedError: {
          description: 'Authentication required',
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/Error' },
              example: {
                error: {
                  message: 'Authentication required',
                  code: 'AUTH_ERROR',
                  status: 401,
                },
              },
            },
          },
        },
        ForbiddenError: {
          description: 'Insufficient permissions',
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/Error' },
              example: {
                error: {
                  message: 'Insufficient permissions',
                  code: 'AUTHZ_ERROR',
                  status: 403,
                },
              },
            },
          },
        },
        NotFoundError: {
          description: 'Resource not found',
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/Error' },
              example: {
                error: {
                  message: 'Resource not found',
                  code: 'NOT_FOUND',
                  status: 404,
                },
              },
            },
          },
        },
        ValidationError: {
          description: 'Validation error',
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/Error' },
              example: {
                error: {
                  message: 'Validation failed',
                  code: 'VALIDATION_ERROR',
                  status: 400,
                  details: [
                    { field: 'email', message: 'Invalid email format' },
                  ],
                },
              },
            },
          },
        },
        RateLimitError: {
          description: 'Rate limit exceeded',
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/Error' },
              example: {
                error: {
                  message: 'Too many requests',
                  code: 'RATE_LIMIT',
                  status: 429,
                },
              },
            },
          },
        },
      },
    },
    tags: [
      {
        name: 'Authentication',
        description: 'User authentication and authorization',
      },
      {
        name: 'Scripts',
        description: 'Script management operations',
      },
      {
        name: 'Recordings',
        description: 'Recording management operations',
      },
      {
        name: 'AI',
        description: 'AI-powered features',
      },
      {
        name: 'Collaboration',
        description: 'Real-time collaboration features',
      },
      {
        name: 'Analytics',
        description: 'Usage analytics and reporting',
      },
      {
        name: 'Subscription',
        description: 'Subscription and billing management',
      },
      {
        name: 'User',
        description: 'User profile and settings',
      },
    ],
  },
  apis: [
    './src/routes/*.ts',
    './src/controllers/*.ts',
  ],
};

const swaggerSpec = swaggerJsdoc(options);

export const setupSwagger = (app: Express): void => {
  // Swagger UI
  app.use(
    '/api-docs',
    swaggerUi.serve,
    swaggerUi.setup(swaggerSpec, {
      explorer: true,
      customCss: '.swagger-ui .topbar { display: none }',
      customSiteTitle: 'TelePrompt Pro API Documentation',
    }),
  );

  // OpenAPI JSON
  app.get('/api-docs.json', (req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.send(swaggerSpec);
  });

  console.log('📚 API documentation available at /api-docs');
};

// Example JSDoc annotations for routes:
/**
 * @swagger
 * /api/auth/signin:
 *   post:
 *     summary: Sign in user
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: user@example.com
 *               password:
 *                 type: string
 *                 format: password
 *                 example: SecurePassword123!
 *     responses:
 *       200:
 *         description: Successfully signed in
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *                 session:
 *                   type: object
 *                   properties:
 *                     accessToken:
 *                       type: string
 *                     refreshToken:
 *                       type: string
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       400:
 *         $ref: '#/components/responses/ValidationError'
 */

/**
 * @swagger
 * /api/scripts:
 *   get:
 *     summary: Get all scripts
 *     tags: [Scripts]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Page number
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *         description: Number of items per page
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *         description: Filter by category
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Search scripts by title or content
 *     responses:
 *       200:
 *         description: List of scripts
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 scripts:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Script'
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     page:
 *                       type: integer
 *                     limit:
 *                       type: integer
 *                     total:
 *                       type: integer
 *                     pages:
 *                       type: integer
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *   post:
 *     summary: Create new script
 *     tags: [Scripts]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - title
 *               - content
 *             properties:
 *               title:
 *                 type: string
 *                 example: My New Script
 *               content:
 *                 type: string
 *                 example: This is the script content...
 *               category:
 *                 type: string
 *                 example: presentation
 *               tags:
 *                 type: array
 *                 items:
 *                   type: string
 *                 example: ['business', 'meeting']
 *     responses:
 *       201:
 *         description: Script created
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Script'
 *       400:
 *         $ref: '#/components/responses/ValidationError'
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 */

export default swaggerSpec;
