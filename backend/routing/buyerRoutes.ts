import Router from "express";
import {register, getProfile} from "../controllers/authController";
import {sellerLimiter, verifyToken} from "../middleware/middleware";
import {availableListings} from "../controllers/buyerControllers";

const router = Router();

router.get("/available_listings", verifyToken, sellerLimiter, availableListings);


export default router;