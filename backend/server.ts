import dotenv from 'dotenv'
dotenv.config();
import express from 'express'
import cors from 'cors'
import authRoutes from "./routing/authRoutes";
import sellerRoutes from "./routing/sellerRoutes";
import buyerRoutes from "./routing/buyerRoutes";

import {verifyToken, sellerLimiter, error_lister} from "./middleware/middleware";
import {availableListings} from "./controllers/buyerControllers";

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(cors());

app.use("/auth", authRoutes);
app.use("/seller", sellerRoutes);

// Direct registration to avoid 404
app.get("/buyer/available_listings", verifyToken, sellerLimiter, (req, res, next) => {
    console.log("Buyer request received at /buyer/available_listings");
    next();
}, availableListings);

app.use("/buyer", buyerRoutes);

app.use(error_lister);


app.listen(PORT, () => {
    console.log(`App is listening on ${PORT}`);
})