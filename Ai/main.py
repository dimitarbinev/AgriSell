import statistics
import firebase_admin
from firebase_admin import credentials, firestore
import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Literal, Optional
from pydantic import BaseModel, Field
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
import os
import asyncio
from math import radians, cos, sin, asin, sqrt
from dotenv import load_dotenv

load_dotenv()

# -------------------------------------------------------
# Firebase setup
# -------------------------------------------------------
db = None
firebase_available = False

try:
    if not firebase_admin._apps:
        service_account_info = {
            "type": os.getenv("FIREBASE_TYPE"),
            "project_id": os.getenv("FIREBASE_PROJECT_ID"),
            "private_key_id": os.getenv("FIREBASE_PRIVATE_KEY_ID"),
            "private_key": os.getenv("FIREBASE_PRIVATE_KEY").replace("\\n", "\n") if os.getenv("FIREBASE_PRIVATE_KEY") else None,
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
            db = firestore.client()
            firebase_available = True
except Exception as e:
    print(f"Firebase initialization error: {e}")

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

# Mapping of Bulgarian cities to coordinates (from AppConstants in Flutter)
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

class PriceRequest(BaseModel):
    product_id: str
    city: str
    season: str
    seller_id: str

class CityModel(BaseModel):
    name: str
    lat: float
    lng: float
    requested_qty: float

class ProduceClassification(BaseModel):
    item: str = Field(description="Името на продукта на български")
    category: Literal["зеленчук", "плод", "месо", "млечен продукт", "друго"] = Field(
        description="Категорията, към която принадлежи продукта"
    )
    confidence: float = Field(description="Увереност на модела от 0 до 1")

class ClassificationRequest(BaseModel):
    product_name: str

class DbRouteRequest(BaseModel):
    seller_id: str
    listing_id: str
    product_id: str
    cost_per_hour: float = 15.0

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
    """
    Returns lat/lng for a city name. 
    First checks local map, then falls back to Google Geocoding API.
    """
    if not city_name: return None
    
    clean_name = city_name.strip().title()
    if clean_name in CITY_LOCATIONS:
        return CITY_LOCATIONS[clean_name]
    
    # Fallback to Google Geocoding
    try:
        url = f"https://maps.googleapis.com/maps/api/geocode/json?address={city_name},Bulgaria&key={MAPS_KEY}"
        async with httpx.AsyncClient() as client:
            r = await client.get(url)
            data = r.json()
            if data.get("status") == "OK":
                loc = data["results"][0]["geometry"]["location"]
                # Cache it for this session (optional)
                CITY_LOCATIONS[clean_name] = {"lat": loc["lat"], "lng": loc["lng"]}
                return CITY_LOCATIONS[clean_name]
    except Exception as e:
        print(f"Geocoding error for {city_name}: {e}")
    
    return None

# --- Classification Setup ---
llm = None
classification_chain = None

if os.getenv("OPENAI_API_KEY"):
    try:
        llm = ChatOpenAI(model="gpt-4o-mini", temperature=0).with_structured_output(ProduceClassification)
        prompt = ChatPromptTemplate.from_messages([
            ("system", "Ти си експерт по хранителни стоки. Твоята задача е да класифицираш продукти на български език в правилни категории."),
            ("human", "Класифицирай следния продукт: {product}")
        ])
        classification_chain = prompt | llm
    except Exception as e:
        print(f"Error initializing OpenAI: {e}")

# -------------------------------------------------------
# Endpoints
# -------------------------------------------------------

@app.post("/classify-product")
async def classify_product(req: ClassificationRequest):
    if not classification_chain:
        # Fallback logic if OpenAI is not configured
        name = req.product_name.lower()
        if "домат" in name or "краставиц" in name:
            return {"item": req.product_name, "category": "зеленчук", "confidence": 1.0}
        return {"item": req.product_name, "category": "друго", "confidence": 0.0}
    
    try:
        result = classification_chain.invoke({"product": req.product_name})
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Classification error: {str(e)}")

@app.post("/predict-price")
async def predict_price(req: PriceRequest):
    if not firebase_available or db is None:
        return {
            "confidence": "medium",
            "suggested_price": 5.50,
            "message": "Firebase not configured. Returning mock data."
        }
    
    try:
        listings_ref = db.collection("listings") \
            .where("productId", "==", req.product_id) \
            .where("city", "==", req.city) \
            .where("status", "in", ["active", "completed"])

        listings = listings_ref.stream()
        prices = [float(listing.to_dict().get("pricePerKg")) for listing in listings if listing.to_dict().get("sellerId") != req.seller_id and listing.to_dict().get("pricePerKg") is not None]

        if len(prices) < 2:
            return {"confidence": "low", "message": "Not enough data."}

        median = statistics.median(prices)
        return {"confidence": "high" if len(prices) >= 5 else "medium", "suggested_price": round(median, 2)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/recommend-route")
async def recommend_route(req: DbRouteRequest):
    """
    Fetches real reservation data for a specific listing from Firestore,
    finds buyer cities, and computes the best routes.
    """
    if not firebase_available or db is None:
        raise HTTPException(status_code=503, detail="Firebase not initialized")

    try:
        # 1. Fetch Seller City
        seller_doc = db.collection("users").document(req.seller_id).get()
        if not seller_doc.exists:
            raise HTTPException(status_code=404, detail="Seller not found")
        
        seller_data = seller_doc.to_dict()
        seller_city_name = seller_data.get("mainCity") or seller_data.get("city")
        seller_coords = await get_coordinates(seller_city_name)
        
        if not seller_coords:
            raise HTTPException(status_code=400, detail=f"Could not find coordinates for seller city: {seller_city_name}")

        # 2. Fetch Product/Listing Data for price and availability
        # Note: Path is users/{sellerId}/products/{productId}/listings/{listingId}
        listing_ref = db.collection("users").document(req.seller_id) \
            .collection("products").document(req.product_id) \
            .collection("listings").document(req.listing_id)
        
        listing_doc = listing_ref.get()
        product_doc = db.collection("users").document(req.seller_id) \
            .collection("products").document(req.product_id).get()
        
        if not listing_doc.exists or not product_doc.exists:
            raise HTTPException(status_code=404, detail="Listing or Product not found")
        
        listing_data = listing_doc.to_dict()
        product_data = product_doc.to_dict()
        
        price_per_kg = float(product_data.get("pricePerKg", 0))
        available_qty = float(product_data.get("maxCapacity", 0)) # Or current available

        # 3. Fetch Reservations for this listing
        reservations_query = db.collection("reservations").where("listingId", "==", req.listing_id).stream()
        
        city_demands = {} # city_name -> total_qty
        
        buyer_ids = set()
        reservation_list = []
        for r in reservations_query:
            r_data = r.to_dict()
            reservation_list.append(r_data)
            buyer_ids.add(r_data.get("buyerId"))

        # 4. Fetch Buyer Cities
        # We fetch all buyers and map them to cities
        buyer_city_map = {} # buyer_id -> city_name
        for b_id in buyer_ids:
            if not b_id: continue
            b_doc = db.collection("users").document(b_id).get()
            if b_doc.exists:
                b_data = b_doc.to_dict()
                buyer_city_map[b_id] = b_data.get("mainCity") or b_data.get("city")

        # 5. Aggregate Demands by City
        for r_data in reservation_list:
            b_id = r_data.get("buyerId")
            qty = float(r_data.get("quantity", 0))
            city_name = buyer_city_map.get(b_id)
            if city_name:
                city_demands[city_name] = city_demands.get(city_name, 0) + qty

        # 6. Convert to Candidates (CityModel)
        candidates = []
        for city_name, qty in city_demands.items():
            if qty < 5: continue # Skip low demand
            
            coords = await get_coordinates(city_name)
            if coords:
                candidates.append(CityModel(
                    name=city_name,
                    lat=coords["lat"],
                    lng=coords["lng"],
                    requested_qty=qty
                ))

        if not candidates:
            return {"options": [], "message": "Няма активни поръчки с достатъчно количество (мин. 5кг на град)."}

        # 7. Compute Routes (Original Logic from mmmmm.py)
        
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

        # 1. Full trip
        task_full = fetch_api_route(candidates, "Пълна обиколка")
        
        # 2. Local trip (within 45km of seller)
        local_cities = [c for c in candidates if get_distance_km(seller_coords['lat'], seller_coords['lng'], c.lat, c.lng) < 45]
        task_local = fetch_api_route(local_cities, "Локален лъч")
        
        # 3. Northern trip (example: Lovech area)
        north_cities = [c for c in candidates if "Ловеч" in c.name or "Плевен" in c.name]
        task_north = fetch_api_route(north_cities, "Северен лъч")

        results = await asyncio.gather(task_full, task_local, task_north)
        
        final_options = []
        seen_routes = []
        for res in results:
            if res and res["ordered_stops"] not in seen_routes:
                final_options.append(res)
                seen_routes.append(res["ordered_stops"])

        return {
            "options": final_options,
            "message": "Маршрутите са изчислени на база реални поръчки от Firestore."
        }

    except Exception as e:
        print(f"Error in recommend_route: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
