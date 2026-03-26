import { Request, Response } from "express";
import admin, { messaging } from "firebase-admin"
import { db } from '../config/firebase'
import { catch_async } from "../middleware/middleware"

export const availableListings = catch_async(async (req: Request, res: Response) => {
    console.log("Available listings request started");
    // 1. Get all sellers (try both lowercase and capitalized just in case)
    const usersSnapshot = await db.collection("users").get();
    const sellers = usersSnapshot.docs.filter(doc => {
        const role = (doc.data().role || "").toLowerCase();
        return role === "seller";
    });
    
    console.log(`Found ${sellers.length} sellers across ${usersSnapshot.size} total users`);
    const allListings: any[] = [];

    for (const sellerDoc of sellers) {
        const sellerData = sellerDoc.data();
        console.log(`Checking seller: ${sellerData.name} (${sellerDoc.id})`);
        
        // 2. Get all products for this seller
        const productsSnapshot = await sellerDoc.ref.collection('products').get();
        console.log(`  - Found ${productsSnapshot.size} products`);

        for (const productDoc of productsSnapshot.docs) {
            const productData = productDoc.data();
            const listingsSnapshot = await productDoc.ref.collection('listings').get();

            for (const listingDoc of listingsSnapshot.docs) {
                const listingData = listingDoc.data();


                allListings.push({
                    id: listingDoc.id,
                    sellerId: sellerDoc.id,
                    sellerName: sellerData.name || "Unknown Seller",
                    sellerRating: sellerData.rating || 0.0,
                    productId: productDoc.id,
                    productName: productData.productName,
                    productCategory: productData.category,
                    productImageUrl: productData.image,
                    pricePerKg: productData.pricePerKg,
                    minThreshold: productData.minThreshold,
                    maxCapacity: productData.maxCapacity,
                    requestedQuantity: listingData.requestedQuantity || 0,
                    city: listingData.city || productData.origin || sellerData.mainCity,
                    date: listingData.date,
                    startTime: listingData.startTime,
                    endTime: listingData.endTime,
                    status: listingData.status,
                });
            }
        }
    }

    return res.status(200).json(allListings);
});


export const placeOrder = catch_async(async (req: Request, res: Response) => {
    const { listingId, quantity, deposit } = req.body;

    if (!listingId || !quantity || !deposit) {
        return res.status(400).json({ message: "Invalid request" })
    }

    const uid = req.user?.uid as string;
    const userRef = await db.collection("users").doc(uid).get();

    if (!userRef.exists) {
        return res.status(404).json({ message: "User not found" });
    }

    const userRole = userRef.data()?.role;
    if (userRole !== "buyer") {
        return res.status(403).json({ message: "User is not a buyer" });
    }

    await db.collection("users").doc(uid).collection('orders').add({
        listingId,
        quantity,
        status: 1,
        createdAt: new Date()
    })

    return res.status(200).json({ message: "Order placed successfully" })
})