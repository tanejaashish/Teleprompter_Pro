import { PrismaClient } from "@prisma/client";
import { Router } from "express";

const router = Router();
const prisma = new PrismaClient();

router.get("/", async (req, res) => {
  try {
    const scripts = await prisma.script.findMany({
      where: { userId: (req as any).user?.userId },
    });
    res.json(scripts);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch scripts" });
  }
});

router.post("/", async (req, res) => {
  try {
    const script = await prisma.script.create({
      data: {
        ...req.body,
        userId: (req as any).user?.userId,
      },
    });
    res.status(201).json(script);
  } catch (error) {
    res.status(500).json({ error: "Failed to create script" });
  }
});

export default router;
