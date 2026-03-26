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
                console.log(`    - Listing ${listingDoc.id}: requestedQuantity in DB = ${listingData.requestedQuantity}`);

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
    const { listingId, quantity, deposit, sellerId, productId } = req.body;
    console.log(`[placeOrder] Request: listingId=${listingId}, qty=${quantity}, sellerId=${sellerId}, productId=${productId}`);

    if (!listingId || quantity === undefined || deposit === undefined || !sellerId || !productId) {
        return res.status(400).json({ message: "Invalid request: missing fields" });
    }

    if (Number(quantity) <= 0 || Number(deposit) < 0) {
        return res.status(400).json({ message: "Quantity must be greater than 0" });
    }

    const uid = req.user?.uid as string;
    const userDoc = await db.collection("users").doc(uid).get();

    if (!userDoc.exists) {
        return res.status(404).json({ message: "User not found" });
    }

    if (userDoc.data()?.role !== "buyer") {
        return res.status(403).json({ message: "User is not a buyer" });
    }

    const buyerName = userDoc.data()?.name || "Anonymous";

    // Refs for atomic transaction
    const listingRef = db.collection("users").doc(sellerId)
        .collection('products').doc(productId)
        .collection('listings').doc(listingId);
    
    const productRef = db.collection("users").doc(sellerId)
        .collection('products').doc(productId);

    try {
        await db.runTransaction(async (transaction) => {
            const listingDoc = await transaction.get(listingRef);
            const productDoc = await transaction.get(productRef);

            if (!listingDoc.exists || !productDoc.exists) {
                throw new Error("Listing or Product not found");
            }

            const listingData = listingDoc.data()!;
            const productData = productDoc.data()!;
            
            const currentQty = Number(listingData.requestedQuantity || 0);
            const requestedQty = Number(quantity);
            const newTotalQty = currentQty + requestedQty;
            const maxCapacity = Number(productData.maxCapacity || 0);
            const minThreshold = Number(productData.minThreshold || 0);

            // 1. Capacity Check
            if (newTotalQty > maxCapacity) {
                throw new Error(`Insufficient capacity. Only ${Math.max(0, maxCapacity - currentQty)} kg remaining.`);
            }

            // 2. Prepare Updates
            const updates: any = {
                requestedQuantity: admin.firestore.FieldValue.increment(requestedQty),
                updatedAt: new Date()
            };

            // 3. Auto-Confirm Logic
            // Status 2 = 'confirmed' per frontend models.dart
            if (newTotalQty >= minThreshold && listingData.status !== 2) {
                updates.status = 2;
                console.log(`[placeOrder] Listing ${listingId} reached threshold (${newTotalQty}/${minThreshold}). Auto-confirming!`);
            }

            transaction.update(listingRef, updates);

            // 4. Create Order record (Private)
            const orderRef = db.collection("users").doc(uid).collection('orders').doc();
            transaction.set(orderRef, {
                listingId, sellerId, productId,
                quantity: requestedQty,
                deposit: Number(deposit),
                status: 1,
                createdAt: new Date()
            });

            // 5. Create Reservation record (Public)
            const resRef = db.collection("reservations").doc();
            transaction.set(resRef, {
                listingId, buyerId: uid, buyerName,
                quantity: requestedQty,
                deposit: Number(deposit),
                status: 'pending',
                createdAt: new Date(),
                attendanceDate: new Date()
            });
        });

        return res.status(200).json({ message: "Order placed successfully" });
    } catch (error: any) {
        console.error(`[placeOrder] Transaction failed:`, error.message);
        return res.status(400).json({ message: error.message });
    }
});

export const getSellerProfile = catch_async(async (req: Request, res: Response) => {
    const { id } = req.params as any;
    const sellerDoc = await db.collection("users").doc(id).get();
    
    if (!sellerDoc.exists) {
        return res.status(404).json({ message: "Seller not found" });
    }
    
    const sellerData = sellerDoc.data()!;
    const allListings: any[] = [];
    
    // Get all products
    const productsSnapshot = await sellerDoc.ref.collection('products').get();
    for (const productDoc of productsSnapshot.docs) {
        const productData = productDoc.data();
        const listingsSnapshot = await productDoc.ref.collection('listings').get();
        for (const listingDoc of listingsSnapshot.docs) {
            const listingData = listingDoc.data();
            allListings.push({
                id: listingDoc.id,
                sellerId: id,
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
    
    return res.status(200).json({
        profile: {
            id: id,
            name: sellerData.name,
            email: sellerData.email,
            phone: sellerData.phoneNumber,
            mainCity: sellerData.mainCity,
            rating: sellerData.rating || 0.0,
            reviewCount: sellerData.reviewCount || 0,
        },
        listings: allListings,
        reviews: [] // Reviews not implemented yet
    });
});