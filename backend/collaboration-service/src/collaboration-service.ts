// Real-Time Collaboration Service
// Implements Operational Transformation for multi-user script editing

import { PrismaClient } from "@prisma/client";
import { Server as SocketIOServer, Socket } from "socket.io";
import { EventEmitter } from "events";
import Redis from "ioredis";
import { createWebSocketRateLimitMiddleware } from "./middleware/websocket-rate-limit";

const prisma = new PrismaClient();
const redis = new Redis(process.env.REDIS_URL || "redis://localhost:6379");

// Operation types for Operational Transformation
export enum OperationType {
  INSERT = "insert",
  DELETE = "delete",
  RETAIN = "retain",
}

export interface Operation {
  type: OperationType;
  position: number;
  text?: string;
  length?: number;
  userId: string;
  timestamp: number;
}

export interface CollaborationSession {
  scriptId: string;
  users: Map<string, UserPresence>;
  documentVersion: number;
  operations: Operation[];
  cursors: Map<string, CursorPosition>;
}

export interface UserPresence {
  userId: string;
  userName: string;
  color: string;
  lastSeen: number;
  cursorPosition?: number;
}

export interface CursorPosition {
  position: number;
  selection?: { start: number; end: number };
}

export class CollaborationService extends EventEmitter {
  private sessions: Map<string, CollaborationSession> = new Map();
  private io: SocketIOServer;

  constructor(io: SocketIOServer) {
    super();
    this.io = io;
    this.setupRateLimiting();
    this.setupSocketHandlers();
  }

  // Setup WebSocket rate limiting
  private setupRateLimiting(): void {
    // Apply connection-level rate limiting
    this.io.use(
      createWebSocketRateLimitMiddleware(redis, {
        points: 100, // 100 messages per minute
        duration: 60,
        blockDuration: 300, // 5 minute block on abuse
      }),
    );

    console.log("WebSocket rate limiting enabled");
  }

  // Setup WebSocket handlers
  private setupSocketHandlers(): void {
    this.io.on("connection", (socket: Socket) => {
      console.log(`Client connected: ${socket.id}`);

      socket.on("join_collaboration", async (data) => {
        await this.handleJoinCollaboration(socket, data);
      });

      socket.on("operation", async (data) => {
        await this.handleOperation(socket, data);
      });

      socket.on("cursor_update", (data) => {
        this.handleCursorUpdate(socket, data);
      });

      socket.on("leave_collaboration", async (data) => {
        await this.handleLeaveCollaboration(socket, data);
      });

      socket.on("disconnect", () => {
        this.handleDisconnect(socket);
      });
    });
  }

  // Handle user joining collaboration session
  private async handleJoinCollaboration(
    socket: Socket,
    data: { scriptId: string; userId: string; userName: string },
  ): Promise<void> {
    const { scriptId, userId, userName } = data;

    // Get or create session
    let session = this.sessions.get(scriptId);
    if (!session) {
      session = await this.createSession(scriptId);
      this.sessions.set(scriptId, session);
    }

    // Add user to session
    const userColor = this.generateUserColor(userId);
    session.users.set(userId, {
      userId,
      userName,
      color: userColor,
      lastSeen: Date.now(),
    });

    // Join socket room
    socket.join(`script:${scriptId}`);
    (socket as any).scriptId = scriptId;
    (socket as any).userId = userId;

    // Send current state to joining user
    socket.emit("collaboration_state", {
      version: session.documentVersion,
      users: Array.from(session.users.values()),
      cursors: Array.from(session.cursors.entries()).map(
        ([uid, cursor]) => ({
          userId: uid,
          ...cursor,
        }),
      ),
    });

    // Notify others
    socket.to(`script:${scriptId}`).emit("user_joined", {
      userId,
      userName,
      color: userColor,
    });

    // Log activity
    await prisma.activity.create({
      data: {
        userId,
        type: "collaboration_joined",
        action: "create",
        entityType: "script",
        entityId: scriptId,
      },
    });

    console.log(`User ${userName} joined collaboration on ${scriptId}`);
  }

  // Handle operation from client
  private async handleOperation(
    socket: Socket,
    data: {
      scriptId: string;
      userId: string;
      operation: Operation;
      clientVersion: number;
    },
  ): Promise<void> {
    const { scriptId, userId, operation, clientVersion } = data;
    const session = this.sessions.get(scriptId);

    if (!session) {
      socket.emit("error", { message: "Session not found" });
      return;
    }

    // Transform operation against concurrent operations
    let transformedOp = operation;
    const concurrentOps = session.operations.filter(
      (op) => op.userId !== userId,
    );

    for (const concOp of concurrentOps) {
      transformedOp = this.transform(transformedOp, concOp);
    }

    // Apply operation
    await this.applyOperation(scriptId, transformedOp);

    // Add to operation history
    session.operations.push(transformedOp);
    session.documentVersion++;

    // Broadcast to other users
    socket.to(`script:${scriptId}`).emit("operation", {
      operation: transformedOp,
      version: session.documentVersion,
      userId,
    });

    // Acknowledge to sender
    socket.emit("operation_ack", {
      version: session.documentVersion,
      operationId: operation.timestamp,
    });
  }

  // Operational Transformation - transform operation against concurrent operation
  private transform(op1: Operation, op2: Operation): Operation {
    // Both insertions
    if (op1.type === OperationType.INSERT && op2.type === OperationType.INSERT) {
      if (op1.position < op2.position) {
        return op1;
      } else if (op1.position > op2.position) {
        return {
          ...op1,
          position: op1.position + (op2.text?.length || 0),
        };
      } else {
        // Same position - use timestamp for tie-breaking
        return op1.timestamp < op2.timestamp
          ? op1
          : {
              ...op1,
              position: op1.position + (op2.text?.length || 0),
            };
      }
    }

    // Both deletions
    if (op1.type === OperationType.DELETE && op2.type === OperationType.DELETE) {
      if (op1.position < op2.position) {
        return op1;
      } else if (op1.position > op2.position) {
        return {
          ...op1,
          position: Math.max(op2.position, op1.position - (op2.length || 0)),
        };
      } else {
        // Overlapping deletions - adjust length
        return {
          ...op1,
          length: Math.max(0, (op1.length || 0) - (op2.length || 0)),
        };
      }
    }

    // Insert vs Delete
    if (op1.type === OperationType.INSERT && op2.type === OperationType.DELETE) {
      if (op1.position <= op2.position) {
        return op1;
      } else if (op1.position >= op2.position + (op2.length || 0)) {
        return {
          ...op1,
          position: op1.position - (op2.length || 0),
        };
      } else {
        // Insert within deleted range
        return {
          ...op1,
          position: op2.position,
        };
      }
    }

    // Delete vs Insert
    if (op1.type === OperationType.DELETE && op2.type === OperationType.INSERT) {
      if (op2.position <= op1.position) {
        return {
          ...op1,
          position: op1.position + (op2.text?.length || 0),
        };
      } else if (op2.position >= op1.position + (op1.length || 0)) {
        return op1;
      } else {
        // Insert within deletion range - split deletion
        return {
          ...op1,
          length: (op1.length || 0) + (op2.text?.length || 0),
        };
      }
    }

    return op1;
  }

  // Apply operation to database
  private async applyOperation(
    scriptId: string,
    operation: Operation,
  ): Promise<void> {
    const script = await prisma.script.findUnique({
      where: { id: scriptId },
    });

    if (!script) {
      throw new Error("Script not found");
    }

    let content = script.content;

    switch (operation.type) {
      case OperationType.INSERT:
        content =
          content.substring(0, operation.position) +
          (operation.text || "") +
          content.substring(operation.position);
        break;

      case OperationType.DELETE:
        content =
          content.substring(0, operation.position) +
          content.substring(operation.position + (operation.length || 0));
        break;
    }

    // Update script
    await prisma.script.update({
      where: { id: scriptId },
      data: {
        content,
        wordCount: this.countWords(content),
        characterCount: content.length,
        updatedAt: new Date(),
      },
    });
  }

  // Handle cursor position updates
  private handleCursorUpdate(
    socket: Socket,
    data: { userId: string; cursor: CursorPosition },
  ): void {
    const scriptId = (socket as any).scriptId;
    const session = this.sessions.get(scriptId);

    if (!session) return;

    session.cursors.set(data.userId, data.cursor);

    // Broadcast to others
    socket.to(`script:${scriptId}`).emit("cursor_update", {
      userId: data.userId,
      cursor: data.cursor,
    });
  }

  // Handle user leaving
  private async handleLeaveCollaboration(
    socket: Socket,
    data: { scriptId: string; userId: string },
  ): Promise<void> {
    const { scriptId, userId } = data;
    const session = this.sessions.get(scriptId);

    if (!session) return;

    session.users.delete(userId);
    session.cursors.delete(userId);

    socket.leave(`script:${scriptId}`);
    socket.to(`script:${scriptId}`).emit("user_left", { userId });

    // Log activity
    await prisma.activity.create({
      data: {
        userId,
        type: "collaboration_left",
        action: "create",
        entityType: "script",
        entityId: scriptId,
      },
    });

    // Clean up session if empty
    if (session.users.size === 0) {
      this.sessions.delete(scriptId);
    }
  }

  // Handle disconnect
  private handleDisconnect(socket: Socket): void {
    const scriptId = (socket as any).scriptId;
    const userId = (socket as any).userId;

    if (scriptId && userId) {
      this.handleLeaveCollaboration(socket, { scriptId, userId });
    }
  }

  // Create new collaboration session
  private async createSession(
    scriptId: string,
  ): Promise<CollaborationSession> {
    const script = await prisma.script.findUnique({
      where: { id: scriptId },
    });

    if (!script) {
      throw new Error("Script not found");
    }

    return {
      scriptId,
      users: new Map(),
      documentVersion: 0,
      operations: [],
      cursors: new Map(),
    };
  }

  // Generate unique color for user
  private generateUserColor(userId: string): string {
    const colors = [
      "#FF6B6B",
      "#4ECDC4",
      "#45B7D1",
      "#FFA07A",
      "#98D8C8",
      "#F7DC6F",
      "#BB8FCE",
      "#85C1E2",
      "#F8B195",
      "#6C5CE7",
    ];

    const hash = userId.split("").reduce((acc, char) => {
      return acc + char.charCodeAt(0);
    }, 0);

    return colors[hash % colors.length];
  }

  // Helper: count words
  private countWords(text: string): number {
    return text.split(/\s+/).filter((w) => w.length > 0).length;
  }

  // Get active sessions
  getActiveSessions(): string[] {
    return Array.from(this.sessions.keys());
  }

  // Get session info
  getSessionInfo(scriptId: string): any {
    const session = this.sessions.get(scriptId);
    if (!session) return null;

    return {
      scriptId,
      users: Array.from(session.users.values()),
      version: session.documentVersion,
      operationCount: session.operations.length,
    };
  }
}
