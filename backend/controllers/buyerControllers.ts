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
                    startDate: listingData.startDate,
                    endDate: listingData.endDate,
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

            if (listingData.status === 3 || listingData.status === 'cancelled') {
                throw new Error("Listing is cancelled and can not take reservations");
            }

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
                sellerId, productId, // adding these
                productName: productData.productName || productData.name || '',
                city: listingData.city || productData.origin || '',
                pricePerKg: Number(productData.pricePerKg || 0),
                quantity: requestedQty,
                deposit: Number(deposit),
                status: 'pending',
                createdAt: new Date(),
                startDate: listingData.startDate || listingData.date || new Date(),
                endDate: listingData.endDate || listingData.date || new Date()
            });
        });

        return res.status(200).json({ message: "Order placed successfully" });
    } catch (error: any) {
        console.error(`[placeOrder] Transaction failed:`, error.message);
        return res.status(400).json({ message: error.message });
    }
});

export const getSellerProfile = catch_async(async (req: Request, res: Response) => {
    const id = req.params.uid || req.params.id as any;
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
                startDate: listingData.startDate,
                endDate: listingData.endDate,
                status: listingData.status,
            });
        }
    }

    // Fetch reviews for this seller
    console.log(`[getSellerProfile] Fetching reviews for sellerId: "${id}"`);
    
    // Attempt string match, and as a fallback we could check for other variations if needed
    const reviewsSnapshot = await db.collection("reviews")
        .where("sellerId", "==", String(id))
        .get();
    
    console.log(`[getSellerProfile] Query complete. Found docs: ${reviewsSnapshot.size}`);

    const reviews = reviewsSnapshot.docs.map(doc => {
        const d = doc.data();
        let timestamp = new Date().toISOString();
        if (d.createdAt) {
            if (typeof d.createdAt.toDate === 'function') timestamp = d.createdAt.toDate().toISOString();
            else if (typeof d.createdAt === 'string') timestamp = d.createdAt;
            else if (d.createdAt._seconds) timestamp = new Date(d.createdAt._seconds * 1000).toISOString();
        }
        
        return {
            id: doc.id,
            ...d,
            createdAt: timestamp
        };
    });

    // Sort descending by creation time
    reviews.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    
    const finalReviews = reviews.slice(0, 30);

    return res.status(200).json({
        profile: {
            id: id,
            name: sellerData.name || "Seller",
            email: sellerData.email || "",
            phone: sellerData.phoneNumber || "",
            mainCity: sellerData.mainCity || "Unknown",
            // Use Number() to ensure it's not a string in the JSON
            rating: Number(sellerData.rating || 0),
            reviewCount: Number(sellerData.reviewCount || sellerData.totalReviews || 0),
        },
        listings: allListings,
        reviews: finalReviews
    });
});

export const getMyReviews = catch_async(async (req: Request, res: Response) => {
    const uid = req.user?.uid;
    if (!uid) return res.status(401).json({ message: "Unauthorized" });

    const snapshot = await db.collection("reviews")
        .where("sellerId", "==", uid)
        .get();

    const reviews = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || new Date().toISOString()
    }));

    reviews.sort((a: any, b: any) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    return res.status(200).json(reviews);
});

export const getMyReservations = catch_async(async (req: Request, res: Response) => {
    const uid = req.user?.uid;
    if (!uid) {
        return res.status(401).json({ message: "Unauthorized" });
    }

    const snapshot = await db.collection("reservations").where("buyerId", "==", uid).get();

    // Fetch orders to help backfill missing sellerId/productId in old reservations
    const ordersSnapshot = await db.collection("users").doc(uid).collection("orders").get();
    const ordersMap = new Map();
    ordersSnapshot.docs.forEach(doc => {
        ordersMap.set(doc.data().listingId, doc.data());
    });

    const reservations: any[] = [];
    for (const doc of snapshot.docs) {
        const data = doc.data();

        // Safely parse dates, whether they are strings, Firestore Timestamps, or JS Dates
        const parseDate = (val: any) => {
            if (!val) return new Date().toISOString();
            if (typeof val.toDate === 'function') return val.toDate().toISOString();
            return new Date(val).toISOString();
        };

        let productName = data.productName;
        let city = data.city;
        let pricePerKg = data.pricePerKg;

        // If old reservation is missing rich data
        if (!productName || pricePerKg === undefined) {
            const orderData = ordersMap.get(data.listingId);
            if (orderData && orderData.sellerId && orderData.productId) {
                const productSnap = await db.collection("users").doc(orderData.sellerId).collection("products").doc(orderData.productId).get();
                if (productSnap.exists) {
                    const pData = productSnap.data()!;
                    productName = pData.productName || pData.name || "Product";
                    pricePerKg = pData.pricePerKg || 0;
                    city = pData.origin || pData.mainCity || "Local";
                }
            }
        }

        reservations.push({
            id: doc.id,
            ...data,
            productName: productName || "Product",
            city: city || "Local",
            pricePerKg: Number(pricePerKg || 0),
            startDate: parseDate(data.startDate || data.attendanceDate),
            endDate: parseDate(data.endDate || data.attendanceDate),
            createdAt: parseDate(data.createdAt),
        });
    }

    return res.status(200).json(reservations);
});

export const cancelReservation = catch_async(async (req: Request, res: Response) => {
    const { reservationId } = req.params as any;
    const uid = req.user?.uid;

    if (!reservationId || !uid) {
        return res.status(400).json({ message: "Reservation ID and UID required" });
    }

    const resRef = db.collection("reservations").doc(reservationId);
    
    try {
        await db.runTransaction(async (transaction: any) => {
            // ─── 1. ALL READS FIRST ───
            const resDoc = await transaction.get(resRef);
            if (!resDoc.exists) {
                throw new Error("Reservation not found");
            }

            const resData = resDoc.data()!;
            if (resData.buyerId !== uid) {
                throw new Error("Unauthorized to cancel this reservation");
            }

            if (resData.status === 'cancelled') {
                throw new Error("Reservation already cancelled");
            }
            if (resData.status === 'confirmed' || resData.status === 'completed') {
                throw new Error("Cannot cancel a confirmed or completed reservation. Please contact the seller.");
            }

            // Read listing info if necessary
            let listingDoc = null;
            let listingRef = null;
            if (resData.sellerId && resData.productId && resData.listingId) {
                listingRef = db.collection("users").doc(resData.sellerId)
                    .collection('products').doc(resData.productId)
                    .collection('listings').doc(resData.listingId);
                listingDoc = await transaction.get(listingRef);
            }

            // Read order info (Regular query - MUST BE BEFORE UPDATES)
            const ordersSnapshot = await db.collection("users").doc(uid).collection("orders")
                .where("listingId", "==", resData.listingId)
                .where("quantity", "==", resData.quantity)
                .get();

            // ─── 2. ALL WRITES AFTER ───
            
            // Mark reservation as cancelled
            transaction.update(resRef, {
                status: 'cancelled',
                updatedAt: new Date()
            });

            // Decrement requestedQuantity on the listing
            if (listingRef && listingDoc && listingDoc.exists) {
                const currentQty = Number(listingDoc.data()?.requestedQuantity || 0);
                const resQty = Number(resData.quantity || 0);
                const newQty = Math.max(0, currentQty - resQty);
                
                transaction.update(listingRef, {
                    requestedQuantity: newQty,
                    updatedAt: new Date()
                });
            }

            // Update the private order status if it exists
            if (!ordersSnapshot.empty) {
                transaction.update(ordersSnapshot.docs[0].ref, {
                    status: 3, // Cancelled
                    updatedAt: new Date()
                });
            }
        });

        return res.status(200).json({ message: "Reservation cancelled successfully" });
    } catch (error: any) {
        console.error(`[cancelReservation] Transaction failed:`, error.message);
        return res.status(400).json({ message: error.message });
    }
});

export const submitReview = catch_async(async (req: Request, res: Response) => {
    const { sellerId, rating, comment } = req.body;
    const buyerId = req.user?.uid;

    if (!sellerId || !rating) {
        return res.status(400).json({ message: "Seller ID and rating are required." });
    }

    const buyerDoc = await db.collection("users").doc(buyerId!).get();
    const buyerName = buyerDoc.data()?.name || "Anonymous";

    const reviewRef = await db.collection("reviews").add({
        sellerId,
        buyerId,
        buyerName,
        rating: Number(rating),
        comment: comment || "",
        createdAt: new Date(),
    });

    // Update Seller's average rating
    const sellerRef = db.collection("users").doc(sellerId);
    const sellerRegistryRef = db.collection("sellers").doc(sellerId);
    
    await db.runTransaction(async (transaction: any) => {
        // ─── 1. ALL READS FIRST ───
        const sellerDoc = await transaction.get(sellerRef);
        const registrySnap = await transaction.get(sellerRegistryRef);

        // ─── 2. ALL WRITES AFTER ───
        if (sellerDoc.exists) {
            const data = sellerDoc.data()!;
            const currentRating = data.rating || 0;
            const currentCount = data.reviewCount || 0;
            const newCount = currentCount + 1;
            const newRating = ((currentRating * currentCount) + Number(rating)) / newCount;

            transaction.update(sellerRef, {
                rating: newRating,
                reviewCount: newCount
            });

            // Also update global sellers registry
            if (registrySnap.exists) {
                transaction.update(sellerRegistryRef, {
                    rating: newRating,
                    reviewCount: newCount
                });
            }
        }
    });

    return res.status(200).json({ id: reviewRef.id, message: "Review submitted successfully" });
});