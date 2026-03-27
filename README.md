# AgriSell

## 🚜 Project Overview

AgriSell is a marketplace app for agriculture products where sellers can create listings and buyers can place orders, reserve items, and review sellers. It includes a Flutter mobile frontend, an Express + TypeScript backend, and Firebase for auth, database, storage, and push notifications.

## 🏗️ Architecture

- **Frontend:** Flutter + Riverpod + GoRouter
- **Backend:** Node.js (TypeScript), Express, Firebase Admin SDK
- **Database:** Firebase Firestore
- **Auth:** Firebase Authentication (email/password + Google Sign-In)
- **Notifications:** Firebase Messaging

## 🌟 Key Features

- Role-based users: buyer and seller
- User registration/login and profile management
- Sellers can add products, manage listings, confirm and update status
- Buyers can browse available listings, place orders, make/cancel reservations, leave reviews
- Map view for location-based seller discovery
- Rate limiting and token verification on API routes

## 📁 Repository Structure

- `/frontend`: Flutter app
  - `lib/features`: feature screens (auth, buyer, seller, notifications)
  - `lib/shared`: models, providers, services, widgets
  - `pubspec.yaml`: Flutter dependencies
- `/backend`: Node backend
  - `server.ts`: Express server entry point
  - `routing/*Routes.ts`: API route declarations
  - `controllers/*Controller.ts`: business logic
  - `middleware/middleware.ts`: auth + rate limit
  - `config/firebase.ts`: firebase initialization
- `/Ai`: utility scripts (scripts, data, bots)

## ⚙️ Setup Instructions

### Backend

1. `cd backend`
2. `npm install`
3. Create `.env` (at `backend/.env` with at least):
   - `PORT` (optional, defaults to 3000)
   - `FIREBASE_SERVICE_ACCOUNT` or Firebase credentials file path
   - `FIREBASE_PROJECT_ID`
4. Run:
   - `npm run dev`

### Frontend

1. `cd frontend`
2. `flutter pub get`
3. Create `.env` with your Firebase config values (or follow existing project docs)
4. Start app:
   - `flutter run`

## 🔌 Backend API Endpoints

### Auth (`/auth`)
- `POST /auth/sign_up` (register)
- `GET /auth/profile` (profile info)
- `POST /auth/change_role` (switch user role)
- `GET /auth/profile_name` (username retrieval)
- `PUT /auth/update_credentials` (update email/password)

### Seller (`/seller`)
- `POST /seller/product` (create product listing)
- `POST /seller/confirmation` (confirm listing)
- `GET /seller/getProducts` (list seller products)
- `GET /seller/getListings` (list seller listings)
- `POST /seller/updateStatus` (update listing status)

### Buyer (`/buyer`)
- `GET /buyer/available_listings` (browse open listings)
- `POST /buyer/place_order` (place new order)
- `GET /buyer/seller/:uid` (seller profile)
- `GET /buyer/my_reservations` (buyer reservations)
- `POST /buyer/cancel_reservation/:reservationId` (cancel reservation)
- `POST /buyer/review` (submit review)
- `GET /buyer/my_reviews` (buyer reviews)

## 🚀 Recommended Dev Workflow

- Frontend: implement UI in `lib/features/*` and call backend via services in `lib/shared/services`
- Backend: add routes in `routing`, implement logic in `controllers`, and secure with middleware
- Use Firebase console for Firestore rules, storage, and messaging config

## 🧪 Testing

- Backend: manual/API tests via Postman or `curl`
- Frontend: Flutter widget/unit tests in `test` (add as needed)

## 💡 Notes

- Make sure your Firebase configuration is consistent between frontend and backend
- Keep dependencies up to date from `package.json` and `pubspec.yaml`
- Add meaningful docs in the `/Ai` folder when adding features to keep sibling scripts manageable

---

Made for AgriSell, a real-world agricultural trade platform supporting buyers and sellers.