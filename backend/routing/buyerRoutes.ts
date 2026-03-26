import Router from "express";
import {register, getProfile} from "../controllers/authController";
import {sellerLimiter, verifyToken} from "../middleware/middleware";
import {availableListings, placeOrder, getSellerProfile} from "../controllers/buyerControllers";

const router = Router();

router.get("/available_listings", verifyToken, sellerLimiter, availableListings);
router.post("/place_order", verifyToken, sellerLimiter, placeOrder);
router.get("/seller/:uid", verifyToken, sellerLimiter, getSellerProfile);


export default router;