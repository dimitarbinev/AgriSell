import Router from "express";
import {register, getProfile} from "../controllers/authController";
import {verifyToken} from "../middleware/middleware";

const router = Router();

router.post("/sign_up", register);
router.get("/profile", verifyToken, getProfile);

export default router;