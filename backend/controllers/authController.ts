import { Request, Response } from "express";
import admin, { messaging } from "firebase-admin"
import {db} from '../config/firebase'
import {catch_async} from "../middleware/middleware"


export const register = catch_async(async (req: Request, res: Response) => {
    console.log("Registration request body:", JSON.stringify(req.body, null, 2));
    const {email, password, name, role} = req.body;

    if(!email || !password || !name || !role) {
        const missing = [];
        if(!email) missing.push('email');
        if(!password) missing.push('password');
        if(!name) missing.push('name');
        if(!role) missing.push('role');
        return res.status(400).json({
            message: `Missing fields: ${missing.join(', ')}. Received keys: ${Object.keys(req.body).join(', ')}`
        });
    }

    const userRecord = await admin.auth().createUser({
        email,
        password,
        displayName: name,
    }) 

    const uid = userRecord.uid;

    if(role === "seller"){
      const baseData = {
        name,
        email,
        role,
        mainCity: req.body.mainCity,
        phoneNumber: req.body.phoneNumber,
        createdAt: new Date()
      };
      await db.collection('users').doc(uid).set(baseData)
      await db.collection('sellers').doc(uid).set({
        ...baseData,
        phone: req.body.phoneNumber // Seller model uses 'phone'
      })
    }

    if(role === "buyer"){
      const baseData = {
        name,
        email,
        role,
        phoneNumber: req.body.phoneNumber,
        preferredCity: req.body.preferredCity,
        createdAt: new Date()
      };
      await db.collection('users').doc(uid).set(baseData)
      await db.collection('buyers').doc(uid).set(baseData)
    }

    return res.status(200).json({message: "User registered successfully"})

})

export const getProfile = catch_async(async (req: Request, res: Response) => {
    const uid = req.user?.uid as string;

    const doc = await db.collection('users').doc(uid).get()

    if (!doc.exists) {
      return res.status(404).json({ message: "Profile not found" });
    }

    res.json({
      uid,
      ...doc.data(),
    });

})

export const changeRole = catch_async(async (req: Request, res: Response) => {
    const uid = req.user?.uid as string; 
    const {role} = req.body;

    if(!role) {
        return res.status(400).json({message: "Invalid role"})
    }

    await db.collection('users').doc(uid).update({
        role,
        updatedAt: new Date()
    })

    return res.status(200).json({message: "Role changed successfully"})
})

export const getProfileName = catch_async(async (req: Request, res: Response) => {
    const uid = req.user?.uid as string;
    const userRef = await db.collection("users").doc(uid).get();

    if (!userRef.exists) {
        return res.status(404).json({ message: "User not found" });
    }

    return res.status(200).json({name: userRef.data()?.name});
})

export const updateCredentials = catch_async(async (req: Request, res: Response) => {
    const uid = req.user?.uid as string;
    const { email, password, name, preferredCity, mainCity, phoneNumber } = req.body;

    const authUpdates: any = {};
    if (email) authUpdates.email = email;
    if (password) authUpdates.password = password;
    if (name) authUpdates.displayName = name;

    if (Object.keys(authUpdates).length > 0) {
        await admin.auth().updateUser(uid, authUpdates);
    }

    const doc = await db.collection('users').doc(uid).get();
    if (!doc.exists) {
        return res.status(404).json({ message: "User not found" });
    }
    const role = doc.data()?.role;

    const firestoreUpdates: any = { updatedAt: new Date() };
    if (name) firestoreUpdates.name = name;
    if (email) firestoreUpdates.email = email;
    if (password) firestoreUpdates.password = password;
    if (phoneNumber) firestoreUpdates.phoneNumber = phoneNumber;
    if (role === 'seller' && mainCity) firestoreUpdates.mainCity = mainCity;
    if (role === 'buyer' && preferredCity) firestoreUpdates.preferredCity = preferredCity;

    await db.collection('users').doc(uid).update(firestoreUpdates);

    if (role === 'seller') {
        const sellerUpdates: any = {};
        if (name) sellerUpdates.name = name;
        if (mainCity) sellerUpdates.mainCity = mainCity;
        if (phoneNumber) sellerUpdates.phone = phoneNumber;
        if (email) sellerUpdates.email = email;
        
        if (Object.keys(sellerUpdates).length > 0) {
            await db.collection('sellers').doc(uid).update(sellerUpdates);
        }
    } else if (role === 'buyer') {
        const buyerUpdates: any = {};
        if (name) buyerUpdates.name = name;
        if (preferredCity) buyerUpdates.preferredCity = preferredCity;
        if (email) buyerUpdates.email = email;
        
        if (Object.keys(buyerUpdates).length > 0) {
            await db.collection('buyers').doc(uid).update(buyerUpdates);
        }
    }

    return res.status(200).json({message: "Credentials updated successfully"});
});