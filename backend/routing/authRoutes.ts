import Router from "express";
import {register, getProfile, changeRole} from "../controllers/authController";
import {verifyToken, authLimiter} from "../middleware/middleware";

const router = Router();

router.post("/sign_up", authLimiter, register);
router.get("/profile", verifyToken, getProfile);
router.post("/change_role", verifyToken, changeRole);

export default router;