import statistics
import firebase_admin
from firebase_admin import credentials, firestore
import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
import asyncio
from math import radians, cos, sin, asin, sqrt
from dotenv import load_dotenv
from Telegram_bot.test import create_application
import logging

load_dotenv()

# Global bot instance
bot_app = None

# -------------------------------------------------------
# Firebase setup
# -------------------------------------------------------
db = None
firebase_available = False

try:
    if not firebase_admin._apps:
        # 1. Try to load from local JSON file
        json_path = os.path.join(os.path.dirname(__file__), "Telegram_bot", "hacktues12-firebase-adminsdk-fbsvc-7ce9f543c1.json")
        
        if os.path.exists(json_path):
            with open(json_path, "r") as f:
                service_account_info = json.load(f)
            
            pk_id = os.getenv("PRIVATE_KEY_ID")
            pk = os.getenv("PRIVATE_KEY")
            if pk_id: service_account_info["private_key_id"] = pk_id
            if pk: service_account_info["private_key"] = pk.replace("\\n", "\n")
            
            cred = credentials.Certificate(service_account_info)
            firebase_admin.initialize_app(cred)
        else:
            # 2. Fallback to individual env vars
            service_account_info = {
                "type": os.getenv("FIREBASE_TYPE"),
                "project_id": os.getenv("FIREBASE_PROJECT_ID"),
                "private_key_id": os.getenv("PRIVATE_KEY_ID") or os.getenv("FIREBASE_PRIVATE_KEY_ID"),
                "private_key": (os.getenv("PRIVATE_KEY") or os.getenv("FIREBASE_PRIVATE_KEY")).replace("\\n", "\n") if (os.getenv("PRIVATE_KEY") or os.getenv("FIREBASE_PRIVATE_KEY")) else None,
                "client_email": os.getenv("FIREBASE_CLIENT_EMAIL"),
                "client_id": os.getenv("FIREBASE_CLIENT_ID"),
                "auth_uri": os.getenv("FIREBASE_AUTH_URI"),
                "token_uri": os.getenv("FIREBASE_TOKEN_URI"),
                "auth_provider_x509_cert_url": os.getenv("FIREBASE_AUTH_PROVIDER_X509_CERT_URL"),
                "client_x509_cert_url": os.getenv("FIREBASE_CLIENT_X509_CERT_URL"),
                "universe_domain": os.getenv("FIREBASE_UNIVERSE_DOMAIN")
            }
            service_account_info = {k: v for k, v in service_account_info.items() if v is not None}
            if service_account_info:
                cred = credentials.Certificate(service_account_info)
                firebase_admin.initialize_app(cred)

    # Always try to get the client if at least one app is initialized
    if firebase_admin._apps:
        db = firestore.client()
        firebase_available = True
        print("✅ Firebase client initialized successfully.")
    else:
        print("❌ No Firebase apps initialized.")
except Exception as e:
    print(f"❌ Firebase initialization error: {e}")

# -------------------------------------------------------
# Config & App Setup
# -------------------------------------------------------
MAPS_KEY = os.getenv("MAPS_KEY")
app = FastAPI(title="Agro Street Market AI")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -------------------------------------------------------
# Constants & Models
# -------------------------------------------------------

# Mapping of Bulgarian cities to coordinates
CITY_LOCATIONS = {
    'Sofia': {'lat': 42.6977, 'lng': 23.3219},
    'Plovdiv': {'lat': 42.1354, 'lng': 24.7453},
    'Varna': {'lat': 43.2141, 'lng': 27.9147},
    'Burgas': {'lat': 42.5048, 'lng': 27.4626},
    'Ruse': {'lat': 43.8356, 'lng': 25.9657},
    'Stara Zagora': {'lat': 42.4258, 'lng': 25.6345},
    'Pleven': {'lat': 43.4170, 'lng': 24.6067},
    'Sliven': {'lat': 42.6817, 'lng': 26.3229},
    'Dobrich': {'lat': 43.5725, 'lng': 27.8273},
    'Shumen': {'lat': 43.2712, 'lng': 26.9361},
    'Pernik': {'lat': 42.6106, 'lng': 23.0292},
    'Haskovo': {'lat': 41.9344, 'lng': 25.5555},
    'Yambol': {'lat': 42.4842, 'lng': 26.5035},
    'Pazardzhik': {'lat': 42.1939, 'lng': 24.3333},
    'Blagoevgrad': {'lat': 42.0209, 'lng': 23.0943},
    'Veliko Tarnovo': {'lat': 43.0757, 'lng': 25.6172},
    'Vratsa': {'lat': 43.2102, 'lng': 23.5529},
    'Gabrovo': {'lat': 42.8742, 'lng': 25.3186},
    'Asenovgrad': {'lat': 42.0125, 'lng': 24.8772},
    'Vidin': {'lat': 43.9961, 'lng': 22.8679},
    'Kazanlak': {'lat': 42.6244, 'lng': 25.3929},
    'Kyustendil': {'lat': 42.2839, 'lng': 22.6911},
    'Montana': {'lat': 43.4125, 'lng': 23.2250},
    'Dimitrovgrad': {'lat': 42.0641, 'lng': 25.5721},
    'Lovech': {'lat': 43.1333, 'lng': 24.7167},
    'Bulgarski Izvor': {'lat': 43.0167, 'lng': 24.2833},
}

class City(BaseModel):
    name: str
    lat: float
    lng: float
    requested_qty: float

class DbRouteRequest(BaseModel):
    seller_id: str
    listing_id: str
    product_id: str
    cost_per_hour: float = 15.0
    start_location_name: str = "Склад на продавача"

class TelegramMessageRequest(BaseModel):
    phone_number: str
    message: str

# -------------------------------------------------------
# Helpers
# -------------------------------------------------------
def format_time(hours_decimal):
    total_minutes = int(hours_decimal * 60)
    h = total_minutes // 60
    m = total_minutes % 60
    return f"{h}h {m}m"

def get_distance_km(lat1, lon1, lat2, lon2):
    R = 6371 
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlat, dlon = lat2 - lat1, lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    return 2 * R * asin(sqrt(a))

async def get_coordinates(city_name: str):
    if not city_name: return None
    clean_name = city_name.strip().title()
    if clean_name in CITY_LOCATIONS:
        return CITY_LOCATIONS[clean_name]
    
    # Google Geocoding Fallback
    try:
        url = f"https://maps.googleapis.com/maps/api/geocode/json?address={city_name},Bulgaria&key={MAPS_KEY}"
        async with httpx.AsyncClient() as client:
            r = await client.get(url)
            data = r.json()
            if data.get("status") == "OK":
                loc = data["results"][0]["geometry"]["location"]
                CITY_LOCATIONS[clean_name] = {"lat": loc["lat"], "lng": loc["lng"]}
                return CITY_LOCATIONS[clean_name]
    except Exception as e:
        print(f"Error geocoding {city_name}: {e}")
    return None

# -------------------------------------------------------
# Endpoint
# -------------------------------------------------------

@app.post("/recommend-route")
async def recommend_route(req: DbRouteRequest):
    if not firebase_available or db is None:
        raise HTTPException(status_code=503, detail="Firebase not available")

    try:
        # 1. Fetch Seller City
        seller_doc = db.collection("users").document(req.seller_id).get()
        if not seller_doc.exists:
            raise HTTPException(status_code=404, detail="Seller profile not found")
        
        seller_data = seller_doc.to_dict()
        seller_city_name = seller_data.get("mainCity") or seller_data.get("city") or "Bulgarski Izvor"
        seller_coords = await get_coordinates(seller_city_name)
        
        if not seller_coords:
            raise HTTPException(status_code=400, detail=f"Coordinates for city '{seller_city_name}' not found")

        # 2. Fetch Product/Listing Info
        product_doc = db.collection("users").document(req.seller_id).collection("products").document(req.product_id).get()
        if not product_doc.exists:
            raise HTTPException(status_code=404, detail="Product not found")
        
        product_data = product_doc.to_dict()
        price_per_kg = float(product_data.get("pricePerKg", 0))
        available_qty = float(product_data.get("maxCapacity", 0))

        # 3. Fetch Reservations for this listing
        reservations_query = db.collection("reservations").where("listingId", "==", req.listing_id).stream()
        
        city_demands = {} # buyer_id -> city & qty
        
        buyer_ids = set()
        res_data_list = []
        for res in reservations_query:
            d = res.to_dict()
            res_data_list.append(d)
            if d.get("buyerId"):
                buyer_ids.add(d.get("buyerId"))

        # 4. Fetch Buyer Locations
        buyer_city_map = {}
        for b_id in buyer_ids:
            b_doc = db.collection("users").document(b_id).get()
            if b_doc.exists:
                b_data = b_doc.to_dict()
                # Prioritize preferredCity from user profile
                buyer_city_map[b_id] = b_data.get("preferredCity") or b_data.get("mainCity") or b_data.get("city")

        # 5. Aggregate demands into City objects
        combined_city_demands = {} # city_name -> qty
        for r_d in res_data_list:
            b_id = r_d.get("buyerId")
            qty = float(r_d.get("quantity", 0))
            city_name = buyer_city_map.get(b_id)
            if city_name:
                combined_city_demands[city_name] = combined_city_demands.get(city_name, 0) + qty

        candidates = []
        for name, qty in combined_city_demands.items():
            if qty < 0.1: continue # Threshold lowered to 0.1 for testing
            coords = await get_coordinates(name)
            if coords:
                candidates.append(City(name=name, lat=coords['lat'], lng=coords['lng'], requested_qty=qty))

        if not candidates:
            return {"options": [], "message": "Няма активни поръчки с достатъчно количество."}

        # --- Sub-algorithm for routes ---
        async def fetch_api_route(subset_cities, label):
            if not subset_cities: return None
            dest = subset_cities[-1]
            wps = subset_cities[:-1]
            origin = f"{seller_coords['lat']},{seller_coords['lng']}"
            destination = f"{dest.lat},{dest.lng}"
            wp_param = f"&waypoints=optimize:true|{'|'.join(f'{c.lat},{c.lng}' for c in wps)}" if wps else ""
            
            url = f"https://maps.googleapis.com/maps/api/directions/json?origin={origin}&destination={destination}{wp_param}&key={MAPS_KEY}"
            async with httpx.AsyncClient() as client:
                r = await client.get(url)
                data = r.json()
                if data.get("status") == "OK":
                    route = data["routes"][0]
                    total_hrs = sum(l["duration"]["value"] for l in route["legs"]) / 3600
                    total_km = sum(l["distance"]["value"] for l in route["legs"]) / 1000
                    
                    order = route.get("waypoint_order", [])
                    stops = [seller_city_name]
                    for idx in order:
                        stops.append(wps[idx].name)
                    stops.append(dest.name)
                    
                    sell_qty = min(sum(c.requested_qty for c in subset_cities), available_qty)
                    profit = (sell_qty * price_per_kg) - (total_hrs * req.cost_per_hour)
                    
                    return {
                        "label": label,
                        "ordered_stops": stops,
                        "travel_time_readable": format_time(total_hrs),
                        "total_travel_hours": round(total_hrs, 2),
                        "total_distance_km": round(total_km, 2),
                        "estimated_profit_bgn": round(profit, 2),
                        "is_profitable": profit > 0
                    }
                return None

        # 6. Generate Scenarios (Full Path and Local Path only)
        task_full = fetch_api_route(candidates, "Пълна обиколка")
        
        local_cities = [c for c in candidates if get_distance_km(seller_coords['lat'], seller_coords['lng'], c.lat, c.lng) < 45]
        task_local = fetch_api_route(local_cities, "Локален лъч")

        results = await asyncio.gather(task_full, task_local)
        
        final_options = []
        seen_routes = []
        for res in results:
            if res and res["ordered_stops"] not in seen_routes:
                final_options.append(res)
                seen_routes.append(res["ordered_stops"])

        return {
            "options": final_options,
            "message": "Маршрутите са изчислени на база реални резервации от Firestore."
        }

    except Exception as e:
        print(f"Algorithm error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.on_event("startup")
async def startup_event():
    global bot_app
    try:
        bot_app = create_application()
        await bot_app.initialize()
        await bot_app.start()
        await bot_app.updater.start_polling()
        print("🚀 Telegram Bot started alongside FastAPI")
    except Exception as e:
        print(f"❌ Error starting Telegram Bot: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    global bot_app
    if bot_app:
        try:
            await bot_app.updater.stop()
            await bot_app.stop()
            await bot_app.shutdown()
            print("🛑 Telegram Bot stopped")
        except Exception as e:
            print(f"❌ Error during Telegram Bot shutdown: {e}")

@app.post("/send-telegram-message")
async def send_telegram_message(req: TelegramMessageRequest):
    if not bot_app:
        raise HTTPException(status_code=503, detail="Telegram bot not initialized")
    
    # 1. Normalize phone
    phone_digits = "".join(filter(str.isdigit, req.phone_number))
    if phone_digits.startswith("359"):
        phone_clean = "0" + phone_digits[3:]
    elif len(phone_digits) == 9 and not phone_digits.startswith("0"):
        phone_clean = "0" + phone_digits
    else:
        phone_clean = phone_digits

    # 2. Find user in Firestore to get chat_id
    if not firebase_available or db is None:
        raise HTTPException(status_code=503, detail="Firebase not available")

    try:
        users_ref = db.collection("users")
        query = users_ref.where("phoneNumber", "==", phone_clean).limit(1).get()
        if not query:
            intl_phone = "+359" + phone_clean[1:] if phone_clean.startswith("0") else phone_clean
            query = users_ref.where("phoneNumber", "==", intl_phone).limit(1).get()

        if not query:
            raise HTTPException(status_code=404, detail=f"User with phone {req.phone_number} not found in Firestore")

        user_data = query[0].to_dict()
        chat_id = user_data.get("telegramChatId")

        if not chat_id:
            raise HTTPException(status_code=400, detail="User has not registered with the Telegram bot yet (telegramChatId missing)")

        # 3. Send message via Telegram bot
        await bot_app.bot.send_message(chat_id=chat_id, text=req.message)
        return {"status": "success", "to": phone_clean, "message": "Sent!"}
        
    except Exception as e:
        print(f"Error sending telegram message: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)