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
# Models
# -------------------------------------------------------
class City(BaseModel):
    name: str
    lat: float
    lng: float
    requested_qty: float

class RouteRequest(BaseModel):
    seller_lat: float
    seller_lng: float
    price_per_kg: float
    available_qty: float
    cost_per_hour: float = 15.0
    cities: list[City]
    prune_threshold_km: float = 15.0  
    start_location_name: str = "Seller's Location"

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

# -------------------------------------------------------
# Endpoint
# -------------------------------------------------------

@app.post("/recommend-route")
async def recommend_route(req: RouteRequest):
    # Филтрираме само активни поръчки
    candidates = [c for c in req.cities if c.requested_qty >= 5]
    if not candidates:
        return {"options": [], "message": "Няма активни поръчки."}

    async def fetch_api_route(subset_cities, label):
        if not subset_cities: return None
        # Последната точка в списъка е дестинация, останалите са waypoints
        dest = subset_cities[-1]
        wps = subset_cities[:-1]
        origin = f"{req.seller_lat},{req.seller_lng}"
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
                
                # Подреждане
                order = route.get("waypoint_order", [])
                stops = [req.start_location_name]
                for idx in order:
                    stops.append(wps[idx].name)
                stops.append(dest.name)
                
                sell_qty = min(sum(c.requested_qty for c in subset_cities), req.available_qty)
                profit = (sell_qty * req.price_per_kg) - (total_hrs * req.cost_per_hour)
                
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

    # Генерираме 3 различни сценария:
    
    # 1. Пълна обиколка (всички градове)
    task_full = fetch_api_route(candidates, "Пълна обиколка")
    
    # 2. Локален лъч (градове до 40 км от Български извор - напр. Албаница, Троян)
    local_cities = [c for c in candidates if get_distance_km(req.seller_lat, req.seller_lng, c.lat, c.lng) < 45]
    task_local = fetch_api_route(local_cities, "Локален лъч (Троян/Албаница)")
    
    # 3. Северен лъч (Ловеч и всичко около него)
    north_cities = [c for c in candidates if "Ловеч" in c.name or "Албаница" in c.name]
    task_north = fetch_api_route(north_cities, "Посока Ловеч")

    results = await asyncio.gather(task_full, task_local, task_north)
    
    # Премахваме празни резултати и дублиращи се маршрути
    final_options = []
    seen_routes = []
    for res in results:
        if res and res["ordered_stops"] not in seen_routes:
            final_options.append(res)
            seen_routes.append(res["ordered_stops"])

    return {
        "options": final_options,
        "message": "Маршрутите са разделени на логични лъчове за по-голяма гъвкавост."
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)