import Router from "express";
import { register, getProfile } from "../controllers/authController";
import { sellerLimiter, verifyToken } from "../middleware/middleware";
import { availableListings, placeOrder, getSellerProfile, getMyReservations, cancelReservation, submitReview, getMyReviews } from "../controllers/buyerControllers";

const router = Router();

router.get("/available_listings", verifyToken, sellerLimiter, availableListings);
router.post("/place_order", verifyToken, sellerLimiter, placeOrder);
router.get("/seller/:uid", verifyToken, sellerLimiter, getSellerProfile);
router.get("/my_reservations", verifyToken, sellerLimiter, getMyReservations);
router.post("/cancel_reservation/:reservationId", verifyToken, cancelReservation);
router.post("/review", verifyToken, submitReview);
router.get("/my_reviews", verifyToken, getMyReviews);

export default router;