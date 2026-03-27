import 'dotenv/config';
import express from 'express'
import cors from 'cors'
import authRoutes from "./routing/authRoutes";
import sellerRoutes from "./routing/sellerRoutes";
import buyerRoutes from "./routing/buyerRoutes";
import aiRoutes from "./routing/aiRoutes";

import {verifyToken, sellerLimiter, error_lister} from "./middleware/middleware";
import {availableListings} from "./controllers/buyerControllers";

const app = express();
app.set('trust proxy', 1);
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(cors());

app.use("/auth", authRoutes);
app.use("/seller", sellerRoutes);
app.use("/ai", aiRoutes);

// Direct registration to avoid 404
app.get("/buyer/available_listings", verifyToken, sellerLimiter, (req, res, next) => {
    console.log("Buyer request received at /buyer/available_listings");
    next();
}, availableListings);

app.use("/buyer", buyerRoutes);

app.use(error_lister);


app.listen(Number(PORT), "0.0.0.0", () => {
    console.log(`App is listening on 0.0.0.0:${PORT}`);
})