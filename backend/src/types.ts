import { DecodedIdToken } from 'firebase-admin/auth'; 

declare global {
  namespace Express {
    interface Request {
      user?: DecodedIdToken; 
    }
  }
}

export enum Status{
  pending,      // 0
  active,       // 1
  go_confirmed, // 2
  cancelled     // 3
}

export interface Product {
  productName: string;
  minThreshold: number;
  maxCapacity: number;
  category: string;
  origin: string;
  image?: string;
  pricePerKg: number;
  availableQuantity: number;
  season?: string;
  sellerId: string;
  createdAt: Date;
  status: Status;
}

export interface Order{
  quantityKg: number;
}