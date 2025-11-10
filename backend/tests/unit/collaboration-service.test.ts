// Comprehensive Test Suite - Collaboration Service
import { describe, it, expect, beforeEach, jest, afterEach } from '@jest/globals';
import { CollaborationService, Operation, OperationType } from '../../collaboration-service/src/collaboration-service';

jest.mock('@prisma/client');
jest.mock('socket.io');

describe('CollaborationService', () => {
  let collaborationService: CollaborationService;
  let mockPrisma: any;

  beforeEach(() => {
    collaborationService = new CollaborationService();
    mockPrisma = {
      script: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      user: {
        findUnique: jest.fn(),
      },
    };
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('joinScript', () => {
    it('should add user to active session', async () => {
      const mockScript = {
        id: 'script_123',
        title: 'Test Script',
        content: 'Initial content',
        userId: 'owner_123',
      };

      mockPrisma.script.findUnique.mockResolvedValue(mockScript);
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'user_123',
        displayName: 'Test User',
      });

      await collaborationService.joinScript('user_123', 'script_123', 'socket_123');

      const session = (collaborationService as any).activeSessions.get('script_123');
      expect(session).toBeDefined();
      expect(session.participants.size).toBe(1);
      expect(session.participants.get('user_123')).toBeDefined();
    });

    it('should throw error for non-existent script', async () => {
      mockPrisma.script.findUnique.mockResolvedValue(null);

      await expect(
        collaborationService.joinScript('user_123', 'invalid_script', 'socket_123'),
      ).rejects.toThrow('Script not found');
    });

    it('should add multiple users to same session', async () => {
      const mockScript = {
        id: 'script_123',
        content: 'Test content',
      };

      mockPrisma.script.findUnique.mockResolvedValue(mockScript);
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user_1', displayName: 'User 1' });

      await collaborationService.joinScript('user_1', 'script_123', 'socket_1');

      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user_2', displayName: 'User 2' });
      await collaborationService.joinScript('user_2', 'script_123', 'socket_2');

      const session = (collaborationService as any).activeSessions.get('script_123');
      expect(session.participants.size).toBe(2);
    });
  });

  describe('leaveScript', () => {
    it('should remove user from session', async () => {
      const mockScript = { id: 'script_123', content: 'Test' };
      mockPrisma.script.findUnique.mockResolvedValue(mockScript);
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user_123', displayName: 'Test' });

      await collaborationService.joinScript('user_123', 'script_123', 'socket_123');
      await collaborationService.leaveScript('user_123', 'script_123');

      const session = (collaborationService as any).activeSessions.get('script_123');
      // Session should be cleaned up if no participants
      expect(session).toBeUndefined();
    });

    it('should keep session alive with remaining participants', async () => {
      const mockScript = { id: 'script_123', content: 'Test' };
      mockPrisma.script.findUnique.mockResolvedValue(mockScript);

      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user_1', displayName: 'User 1' });
      await collaborationService.joinScript('user_1', 'script_123', 'socket_1');

      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user_2', displayName: 'User 2' });
      await collaborationService.joinScript('user_2', 'script_123', 'socket_2');

      await collaborationService.leaveScript('user_1', 'script_123');

      const session = (collaborationService as any).activeSessions.get('script_123');
      expect(session).toBeDefined();
      expect(session.participants.size).toBe(1);
    });
  });

  describe('submitOperation', () => {
    it('should apply INSERT operation', async () => {
      const mockScript = { id: 'script_123', content: 'Hello' };
      mockPrisma.script.findUnique.mockResolvedValue(mockScript);
      mockPrisma.script.update.mockResolvedValue({});
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user_123', displayName: 'Test' });

      await collaborationService.joinScript('user_123', 'script_123', 'socket_123');

      const operation: Operation = {
        type: OperationType.INSERT,
        position: 5,
        text: ' World',
        userId: 'user_123',
        timestamp: Date.now(),
      };

      const result = await collaborationService.submitOperation('script_123', operation);

      expect(result).toBeDefined();
      expect(mockPrisma.script.update).toHaveBeenCalled();
    });

    it('should apply DELETE operation', async () => {
      const mockScript = { id: 'script_123', content: 'Hello World' };
      mockPrisma.script.findUnique.mockResolvedValue(mockScript);
      mockPrisma.script.update.mockResolvedValue({});
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user_123', displayName: 'Test' });

      await collaborationService.joinScript('user_123', 'script_123', 'socket_123');

      const operation: Operation = {
        type: OperationType.DELETE,
        position: 5,
        length: 6,
        userId: 'user_123',
        timestamp: Date.now(),
      };

      const result = await collaborationService.submitOperation('script_123', operation);

      expect(result).toBeDefined();
      expect(mockPrisma.script.update).toHaveBeenCalled();
    });

    it('should throw error for invalid session', async () => {
      const operation: Operation = {
        type: OperationType.INSERT,
        position: 0,
        text: 'test',
        userId: 'user_123',
        timestamp: Date.now(),
      };

      await expect(
        collaborationService.submitOperation('invalid_script', operation),
      ).rejects.toThrow('Session not found');
    });
  });

  describe('Operational Transformation', () => {
    it('should transform concurrent INSERT operations', () => {
      const op1: Operation = {
        type: OperationType.INSERT,
        position: 5,
        text: 'ABC',
        userId: 'user_1',
        timestamp: Date.now(),
      };

      const op2: Operation = {
        type: OperationType.INSERT,
        position: 10,
        text: 'XYZ',
        userId: 'user_2',
        timestamp: Date.now(),
      };

      const transformed = (collaborationService as any).transform(op1, op2);

      // op1 should not be affected since it's before op2
      expect(transformed.position).toBe(5);
    });

    it('should transform INSERT after DELETE', () => {
      const deleteOp: Operation = {
        type: OperationType.DELETE,
        position: 5,
        length: 3,
        userId: 'user_1',
        timestamp: Date.now(),
      };

      const insertOp: Operation = {
        type: OperationType.INSERT,
        position: 10,
        text: 'ABC',
        userId: 'user_2',
        timestamp: Date.now(),
      };

      const transformed = (collaborationService as any).transform(insertOp, deleteOp);

      // Insert position should shift left by delete length
      expect(transformed.position).toBe(7);
    });

    it('should handle overlapping DELETE operations', () => {
      const op1: Operation = {
        type: OperationType.DELETE,
        position: 5,
        length: 10,
        userId: 'user_1',
        timestamp: Date.now(),
      };

      const op2: Operation = {
        type: OperationType.DELETE,
        position: 8,
        length: 5,
        userId: 'user_2',
        timestamp: Date.now(),
      };

      const transformed = (collaborationService as any).transform(op1, op2);

      expect(transformed).toBeDefined();
      // Should handle overlap correctly
    });
  });

  describe('updateCursor', () => {
    it('should update user cursor position', async () => {
      const mockScript = { id: 'script_123', content: 'Test' };
      mockPrisma.script.findUnique.mockResolvedValue(mockScript);
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user_123', displayName: 'Test' });

      await collaborationService.joinScript('user_123', 'script_123', 'socket_123');

      const cursorPosition = {
        position: 10,
        selection: { start: 10, end: 15 },
      };

      await collaborationService.updateCursor('user_123', 'script_123', cursorPosition);

      const session = (collaborationService as any).activeSessions.get('script_123');
      const participant = session.participants.get('user_123');
      expect(participant.cursor).toEqual(cursorPosition);
    });
  });

  describe('getActiveParticipants', () => {
    it('should return list of active users', async () => {
      const mockScript = { id: 'script_123', content: 'Test' };
      mockPrisma.script.findUnique.mockResolvedValue(mockScript);

      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user_1', displayName: 'User 1' });
      await collaborationService.joinScript('user_1', 'script_123', 'socket_1');

      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user_2', displayName: 'User 2' });
      await collaborationService.joinScript('user_2', 'script_123', 'socket_2');

      const participants = collaborationService.getActiveParticipants('script_123');

      expect(participants).toHaveLength(2);
      expect(participants[0].userId).toBe('user_1');
      expect(participants[1].userId).toBe('user_2');
    });

    it('should return empty array for non-existent session', () => {
      const participants = collaborationService.getActiveParticipants('invalid_script');
      expect(participants).toEqual([]);
    });
  });

  describe('event emissions', () => {
    it('should emit user_joined event', async (done) => {
      const mockScript = { id: 'script_123', content: 'Test' };
      mockPrisma.script.findUnique.mockResolvedValue(mockScript);
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user_123', displayName: 'Test User' });

      collaborationService.on('user_joined', (data) => {
        expect(data.scriptId).toBe('script_123');
        expect(data.userId).toBe('user_123');
        expect(data.userName).toBe('Test User');
        done();
      });

      await collaborationService.joinScript('user_123', 'script_123', 'socket_123');
    });

    it('should emit operation_applied event', async (done) => {
      const mockScript = { id: 'script_123', content: 'Test' };
      mockPrisma.script.findUnique.mockResolvedValue(mockScript);
      mockPrisma.script.update.mockResolvedValue({});
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user_123', displayName: 'Test' });

      await collaborationService.joinScript('user_123', 'script_123', 'socket_123');

      collaborationService.on('operation_applied', (data) => {
        expect(data.scriptId).toBe('script_123');
        expect(data.operation).toBeDefined();
        done();
      });

      const operation: Operation = {
        type: OperationType.INSERT,
        position: 0,
        text: 'New',
        userId: 'user_123',
        timestamp: Date.now(),
      };

      await collaborationService.submitOperation('script_123', operation);
    });
  });

  describe('conflict resolution', () => {
    it('should resolve conflicts with version vectors', async () => {
      const mockScript = { id: 'script_123', content: 'Original content' };
      mockPrisma.script.findUnique.mockResolvedValue(mockScript);
      mockPrisma.script.update.mockResolvedValue({});
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user_1', displayName: 'User 1' });

      await collaborationService.joinScript('user_1', 'script_123', 'socket_1');

      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user_2', displayName: 'User 2' });
      await collaborationService.joinScript('user_2', 'script_123', 'socket_2');

      // Submit concurrent operations
      const op1: Operation = {
        type: OperationType.INSERT,
        position: 5,
        text: 'User1',
        userId: 'user_1',
        timestamp: Date.now(),
      };

      const op2: Operation = {
        type: OperationType.INSERT,
        position: 5,
        text: 'User2',
        userId: 'user_2',
        timestamp: Date.now() + 1,
      };

      await collaborationService.submitOperation('script_123', op1);
      await collaborationService.submitOperation('script_123', op2);

      // Both operations should be applied with transformation
      expect(mockPrisma.script.update).toHaveBeenCalledTimes(2);
    });
  });
});
