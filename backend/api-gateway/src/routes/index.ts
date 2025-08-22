import { Router } from "express";
import authRoutes from "./auth";
import scriptsRoutes from "./scripts";

const router = Router();

router.use("/auth", authRoutes);
router.use("/scripts", scriptsRoutes);

export default router;
