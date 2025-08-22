import { PrismaClient } from "@prisma/client";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";

const prisma = new PrismaClient();

export class AuthService {
  static async generateTokens(userId: string) {
    const accessToken = jwt.sign(
      { userId, type: "access" },
      process.env.JWT_SECRET!,
      { expiresIn: "15m" },
    );

    const refreshToken = jwt.sign(
      { userId, type: "refresh" },
      process.env.JWT_REFRESH_SECRET!,
      { expiresIn: "7d" },
    );

    return { accessToken, refreshToken };
  }

  static async validatePassword(password: string, hash: string) {
    return bcrypt.compare(password, hash);
  }

  static async hashPassword(password: string) {
    return bcrypt.hash(password, 10);
  }

  static async verifyToken(token: string, type: "access" | "refresh") {
    const secret =
      type === "access"
        ? process.env.JWT_SECRET!
        : process.env.JWT_REFRESH_SECRET!;

    return jwt.verify(token, secret);
  }
}
