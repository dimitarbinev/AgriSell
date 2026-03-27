import { Request, Response } from "express";
import { catch_async } from "../middleware/middleware";

const AI_SERVICE_URL = process.env.AI_SERVICE_URL;

export const classifyProduct = catch_async(async (req: Request, res: Response) => {
    const { productName } = req.body;

    if (!productName) {
        return res.status(400).json({ message: "productName is required" });
    }

    try {
        const response = await fetch(`${AI_SERVICE_URL}/classify-product`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ product_name: productName }),
        });

        if (!response.ok) {
            const error = await response.text();
            throw new Error(`AI service responded with ${response.status}: ${error}`);
        }

        const data = await response.json();
        return res.status(200).json(data);
    } catch (error: any) {
        console.error("Error calling AI service:", error);
        return res.status(500).json({ message: "Failed to classify product", error: error.message });
    }
});
