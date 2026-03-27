import { Request, Response } from "express";
import admin, { messaging } from "firebase-admin"
import {db} from '../config/firebase'
import {catch_async} from "../middleware/middleware"
import { Product, Status } from "../src/types.js";

export const productListing = catch_async(async (req: Request, res: Response) => {
    const productData: Partial<Product> = req.body;

    const requiredFields = ['productName', 'minThreshold', 'maxCapacity', 'origin', 'pricePerKg', 'availableQuantity'];
    const missingFields = requiredFields.filter(field => !productData[field as keyof Product]);

    if (missingFields.length > 0) {
        console.log("Missing fields in product listing:", missingFields);
        return res.status(400).json({
            message: `Missing fields: ${missingFields.join(', ')}`
        });
    }

    // Auto-classify category if missing
    let category = productData.category;
    if (!category && productData.productName) {
        try {
            const AI_SERVICE_URL = process.env.AI_SERVICE_URL;
            const aiRes = await fetch(`${AI_SERVICE_URL}/classify-product`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ product_name: productData.productName }),
            });
            console.log(aiRes);
            if (aiRes.ok) {
                const aiData = await aiRes.json() as any;
                category = aiData.category;
                console.log(`AI classified ${productData.productName} as ${category}`);
            }
        } catch (err) {
            console.error("AI Classification failed, falling back to 'Други':", err);
            category = "Други";
        }
    }

    if (!category) category = "Други";

    const uid = req.user?.uid as string;
    const userRef = await db.collection("users").doc(uid).get();

    if (!userRef.exists) {
        return res.status(404).json({ message: "User not found" });
    }

    const userRole = userRef.data()?.role;
    if (userRole !== "seller") {
        return res.status(403).json({ message: "User is not a seller" });
    }

    await db.collection("users").doc(uid).collection('products').add({
        productName: productData.productName,
        minThreshold: productData.minThreshold,
        maxCapacity: productData.maxCapacity,
        category: category,
        image: productData.image,
        origin: productData.origin,
        pricePerKg: productData.pricePerKg,
        availableQuantity: productData.availableQuantity,
        season: productData.season,
        sellerId: uid,
        createdAt: new Date()
    })

    return res.status(200).json({message: "Product listed successfully"})
})

export const listingConfirmation = catch_async(async (req: Request, res: Response) => {
    const {productId, startDate, endDate} = req.body;

    if(!productId || !startDate || !endDate) {
        return res.status(400).json({message: "Invalid request"})
    }

    const uid = req.user?.uid as string;
    const userRef = await db.collection("users").doc(uid).get();

    if (!userRef.exists) {
        return res.status(404).json({ message: "User not found" });
    }

    const userRole = userRef.data()?.role;
    if (userRole !== "seller") {
        return res.status(403).json({ message: "User is not a seller" });
    }

    await db.collection("users").doc(uid).collection('products').doc(productId).collection("listings").add({
        startDate,
        endDate,
        status: Status.active,
        updatedAt: new Date()
    });

    // CRITICAL: Trigger snapshot listener on parent collection
    await db.collection("users").doc(uid).collection('products').doc(productId).update({
        lastListingAt: new Date() // Forces parent snapshots to fire
    });

    return res.status(200).json({message: "Listing confirmed successfully"})
})

export const getProducts = catch_async(async (req: Request, res: Response) => {
    const uid = req.user?.uid as string;
    const snapshot = await db.collection("users").doc(uid).collection('products').get();
    const products = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    return res.status(200).json(products);
});

export const getListings = catch_async(async (req: Request, res: Response) => {
    const uid = req.user?.uid as string;
    const snapshot = await db.collection("users").doc(uid).collection('products').get();
    const listings: any[] = [];

    for (const productDoc of snapshot.docs) {
        const productData = productDoc.data();
        const listingsSnapshot = await productDoc.ref.collection('listings').get();

        for (const listingDoc of listingsSnapshot.docs) {
            const listingData = listingDoc.data();
            listings.push({
                id: listingDoc.id,
                sellerId: uid,
                productId: productDoc.id,
                productName: productData.productName,
                productCategory: productData.category,
                city: listingData.city || '',
                startDate: listingData.startDate,
                endDate: listingData.endDate,
                pricePerKg: productData.pricePerKg,
                availableQuantity: productData.maxCapacity,
                minThreshold: productData.minThreshold,
                requestedQuantity: listingData.requestedQuantity || 0,
                status: listingData.status,
                productImageUrl: productData.image || null,
            });
        }
    }

    return res.status(200).json(listings);
});

export const updateListingStatus = catch_async(async (req: Request, res: Response) => {
    const { productId, listingId, status } = req.body;

    if (!productId || !listingId || status === undefined) {
        return res.status(400).json({ message: "Invalid request: productId, listingId, and status are required" });
    }

    const uid = req.user?.uid as string;
    const userRef = await db.collection("users").doc(uid).get();

    if (!userRef.exists) {
        return res.status(404).json({ message: "User not found" });
    }

    const sellerDoc = await db.collection("users").doc(uid).collection('products').doc(productId).collection("listings").doc(listingId).get();
    if (!sellerDoc.exists) {
        return res.status(404).json({ message: "Listing not found" });
    }

    await db.collection("users").doc(uid).collection('products').doc(productId).collection("listings").doc(listingId).update({
        status: Number(status),
        updatedAt: new Date()
    });

    return res.status(200).json({ message: "Listing status updated successfully" });
});