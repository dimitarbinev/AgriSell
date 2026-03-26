import { Request, Response } from "express";
import admin, { messaging } from "firebase-admin"
import {db} from '../config/firebase'
import {catch_async} from "../middleware/middleware"
import { Product, Status } from "../src/types.js";

export const productListing = catch_async(async (req: Request, res: Response) => {
    const productData: Partial<Product> = req.body;

    if(!productData.productName || !productData.minThreshold || !productData.maxCapacity || !productData.category || !productData.origin || !productData.image || !productData.pricePerKg) {
        return res.status(400).json({message: "All fields are required"})
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

    await db.collection("users").doc(uid).collection('products').add({
        productName: productData.productName,
        minThreshold: productData.minThreshold,
        maxCapacity: productData.maxCapacity,
        category: productData.category,
        image: productData.image,
        origin: productData.origin,
        pricePerKg: productData.pricePerKg,
        season: productData.season,
        sellerId: uid,
        createdAt: new Date()
    })

    return res.status(200).json({message: "Product listed successfully"})
})

export const listingConfirmation = catch_async(async (req: Request, res: Response) => {
    const {productId, date, startTime, endTime} = req.body;

    if(!productId || !date || !startTime || !endTime) {
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
        date,
        startTime,
        endTime,
        status: Status.confirmed,
        updatedAt: new Date()
    })

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
                date: listingData.date,
                startTime: listingData.startTime,
                endTime: listingData.endTime,
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
