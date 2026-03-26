import Router from "express";
import {register, getProfile} from "../controllers/authController";
import {sellerLimiter, verifyToken} from "../middleware/middleware";
import {productListing, listingConfirmation, getProducts} from "../controllers/sellerControllers";

const router = Router();

router.post("/product",verifyToken,sellerLimiter, productListing);
router.post("/confirmation",verifyToken,sellerLimiter, listingConfirmation);
router.get("/getProducts", verifyToken,sellerLimiter, getProducts)

export default router;