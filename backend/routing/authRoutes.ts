import Router from "express";
import {register, getProfile, changeRole, getProfileName, updateCredentials} from "../controllers/authController.js";
import {verifyToken, authLimiter} from "../middleware/middleware.js";

const router = Router();

router.post("/sign_up", authLimiter, register);
router.get("/profile", verifyToken, getProfile);
router.post("/change_role", verifyToken, changeRole);
router.get("/profile_name", verifyToken, getProfileName);
router.put("/update_credentials", verifyToken, updateCredentials);

export default router;