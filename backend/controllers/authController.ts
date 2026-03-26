import { Request, Response } from "express";
import admin, { messaging } from "firebase-admin"
import {db} from '../config/firebase'
import {catch_async} from "../middleware/middleware"


export const register = catch_async(async (req: Request, res: Response) => {
    const {email, password, name, role} = req.body;

    if(!email || !password || !name) {
        return res.status(400).json({message: "All fields are required"})
    }

    if(!role) {
        return res.status(400).json({message: "Invalid role"})
    }

    const userRecord = await admin.auth().createUser({
        email,
        password,
        displayName: name,
    }) 

    const uid = userRecord.uid;

    if(role === "seller"){
      await db.collection('users').doc(uid).set({
        name,
        email,
        password,
        role,
        mainCity: req.body.mainCity,
        phoneNumber: req.body.phoneNumber,
        createdAt: new Date()
      })
    }

    if(role === "buyer"){
      await db.collection('users').doc(uid).set({
        name,
        email,
        password,
        role,
        preferredCity: req.body.preferredCity,
        createdAt: new Date()
      })
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