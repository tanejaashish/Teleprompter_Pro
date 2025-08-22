import { Server, Socket } from "socket.io";

export class SyncService {
  private io: Server;
  private userSockets: Map<string, Set<string>> = new Map();

  constructor(io: Server) {
    this.io = io;
  }

  handleConnection(socket: Socket) {
    socket.on("join", (userId: string) => {
      if (!this.userSockets.has(userId)) {
        this.userSockets.set(userId, new Set());
      }
      this.userSockets.get(userId)!.add(socket.id);
      socket.join(`user:${userId}`);
    });

    socket.on("sync:script", (data: any) => {
      socket.to(`user:${data.userId}`).emit("sync:script:update", data);
    });

    socket.on("disconnect", () => {
      // Clean up user socket mappings
      for (const [userId, sockets] of this.userSockets.entries()) {
        if (sockets.has(socket.id)) {
          sockets.delete(socket.id);
          if (sockets.size === 0) {
            this.userSockets.delete(userId);
          }
        }
      }
    });
  }
}
