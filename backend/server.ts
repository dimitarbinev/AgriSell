import dotenv from 'dotenv'
dotenv.config();
import express from 'express'
import cors from 'cors'
import authRoutes from "./routing/authRoutes";

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(cors());
app.use("/auth", authRoutes);

        
app.listen(PORT, () => {
    console.log(`App is listening on ${PORT}`);
})


