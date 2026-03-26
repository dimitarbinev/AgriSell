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

    if (!listingId || !quantity || !deposit || !sellerId || !productId) {
        return res.status(400).json({ message: "Invalid request: missing fields" })
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

    // 1. Create order for the buyer (private)
    const orderData = {
        listingId,
        sellerId,
        productId,
        quantity: Number(quantity),
        deposit: Number(deposit),
        status: 1,
        createdAt: new Date()
    };
    console.log(`[placeOrder] Saving order to buyer ${uid}:`, orderData);
    await db.collection("users").doc(uid).collection('orders').add(orderData);

    // 2. Create reservation (shared/public visibility for the listing)
    const buyerName = userRef.data()?.name || "Anonymous";
    console.log(`[placeOrder] Creating shared reservation for listingId: "${listingId}"`);
    const reservationData = {
        listingId,
        buyerId: uid,
        buyerName,
        quantity: Number(quantity),
        deposit: Number(deposit),
        status: 'pending',
        createdAt: new Date(),
        attendanceDate: new Date() // Added for model compatibility
    };
    console.log(`[placeOrder] Reservation data object:`, JSON.stringify(reservationData));
    await db.collection("reservations").add(reservationData);

    // 3. Increment listing progress
    const listingRef = db.collection("users").doc(sellerId)
        .collection('products').doc(productId)
        .collection('listings').doc(listingId);

    console.log(`[placeOrder] Incrementing requestedQuantity by ${quantity} for listing ${listingId}`);
    await listingRef.update({
        requestedQuantity: admin.firestore.FieldValue.increment(Number(quantity)),
        updatedAt: new Date()
    });

    const updatedDoc = await listingRef.get();
    console.log(`[placeOrder] VERIFY: New requestedQuantity in DB for ${listingId} is: ${updatedDoc.data()?.requestedQuantity}`);

    return res.status(200).json({ message: "Order placed successfully" })
})

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