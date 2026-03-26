import statistics
import firebase_admin
from firebase_admin import credentials, firestore
import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
from dotenv import load_dotenv

load_dotenv()

# -------------------------------------------------------
# Firebase setup
# -------------------------------------------------------
db = None
firebase_available = False

try:
    # Check if already initialized to prevent ValueError during development server reloads
    if not firebase_admin._apps:
        # Load credentials from .env
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
        
        # Filter out None values
        service_account_info = {k: v for k, v in service_account_info.items() if v is not None}
        
        if service_account_info:
            cred = credentials.Certificate(service_account_info)
            firebase_admin.initialize_app(cred)
        else:
            print("WARNING: Firebase credentials not found in .env")
    
    db = firestore.client()
    firebase_available = True
except Exception as e:
    print(f"Firebase initialization error: {e}")
# -------------------------------------------------------
# Config
# -------------------------------------------------------
MAPS_KEY = os.getenv("MAPS_KEY")

if not MAPS_KEY:
    print("WARNING: MAPS_KEY not found in .env file!")

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

class PriceRequest(BaseModel):
    product_id: str
    city: str
    season: str          # "spring" | "summer" | "autumn" | "winter"
    seller_id: str       # excluded from comparison


class City(BaseModel):
    name: str
    lat: float
    lng: float
    requested_qty: float  # kg demanded in this city


class RouteRequest(BaseModel):
    seller_lat: float
    seller_lng: float
    price_per_kg: float
    available_qty: float
    cost_per_hour: float = 15.0   # BGN — seller can override
    cities: list[City]


# -------------------------------------------------------
# /predict-price
# -------------------------------------------------------

@app.post("/predict-price")
async def predict_price(req: PriceRequest):
    """
    Looks at all other sellers listing the same product in the same city
    and returns a recommended price based on the market.
    """
    if not firebase_available or db is None:
        # Return mock data instead of 503 so frontend can still test the endpoint
        return {
            "confidence": "medium",
            "suggested_price": 5.50,
            "price_range_min": 4.00,
            "price_range_max": 7.00,
            "market_average": 5.25,
            "vs_market": "inline with market",
            "based_on_listings": 0,
            "message": "Firebase not configured. Returning mock data."
        }
    
    try:
        assert db is not None
        listings_ref = db.collection("listings") \
            .where("productId", "==", req.product_id) \
            .where("city", "==", req.city) \
            .where("status", "in", ["active", "completed"])

        listings = listings_ref.stream()
        prices = []

        for listing in listings:
            data = listing.to_dict()
            # Exclude the requesting seller's own listings
            if data.get("sellerId") != req.seller_id:
                price = data.get("pricePerKg")
                if price is not None:
                    prices.append(float(price))

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Firestore error: {str(e)}")

    if len(prices) < 2:
        return {
            "confidence": "low",
            "message": "Not enough data in this city yet. Price freely.",
            "suggested_price": None,
            "price_range_min": None,
            "price_range_max": None,
            "market_average": None,
            "based_on_listings": len(prices),
        }

    avg = statistics.mean(prices)
    median = statistics.median(prices)
    low = min(prices)
    high = max(prices)

    # Tell the seller where they stand vs the market
    if median < avg * 0.95:
        vs_market = "below average — good for demand"
    elif median > avg * 1.05:
        vs_market = "above average — risk of lower demand"
    else:
        vs_market = "inline with market"

    return {
        "confidence": "high" if len(prices) >= 5 else "medium",
        "suggested_price": round(median, 2),
        "price_range_min": round(low, 2),
        "price_range_max": round(high, 2),
        "market_average": round(avg, 2),
        "vs_market": vs_market,
        "based_on_listings": len(prices),
    }


# -------------------------------------------------------
# /recommend-route
# -------------------------------------------------------

@app.post("/recommend-route")
async def recommend_route(req: RouteRequest):
    """
    Returns three different route options with profitability for seller to choose from.
    Uses Google Maps to find optimal stop order, then calculates expected profit for each option.
    """
    # Drop cities with negligible demand
    candidates = [c for c in req.cities if c.requested_qty >= 5]

    if not candidates:
        return {
            "options": [],
            "message": "No city has enough demand to justify the trip.",
        }

    # Generate top 3 overall quickest route options
    options = []
    
    import asyncio
    async def fetch_route_for_dest(dest_idx):
        dest_candidate = candidates[dest_idx]
        wp_candidates = [c for i, c in enumerate(candidates) if i != dest_idx]
        
        origin = f"{req.seller_lat},{req.seller_lng}"
        destination = f"{dest_candidate.lat},{dest_candidate.lng}"
        
        waypoints_param = ""
        if wp_candidates:
            waypoints_param = "&waypoints=optimize:true|" + "|".join(
                f"{c.lat},{c.lng}" for c in wp_candidates
            )
        
        url = (
            f"https://maps.googleapis.com/maps/api/directions/json"
            f"?origin={origin}"
            f"&destination={destination}"
            f"{waypoints_param}"
            f"&alternatives=true"
            f"&key={MAPS_KEY}"
        )
        async with httpx.AsyncClient() as client:
            r = await client.get(url)
            return r.json(), wp_candidates, dest_candidate

    try:
        tasks = [fetch_route_for_dest(i) for i in range(len(candidates))]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        all_routes = []
        for res in results:
            if isinstance(res, Exception):
                continue
            data, wp_candidates, dest_candidate = res
            if data.get("status") == "OK":
                for route in data.get("routes", []):
                    legs = route["legs"]
                    total_seconds = sum(l["duration"]["value"] for l in legs)
                    total_hours = total_seconds / 3600
                    total_meters = sum(l["distance"]["value"] for l in legs)
                    total_km = total_meters / 1000

                    waypoint_order = route.get("waypoint_order", [])
                    if waypoint_order:
                        ordered_waypoints = [wp_candidates[i] for i in waypoint_order]
                    else:
                        ordered_waypoints = wp_candidates
                    
                    ordered_cities = ordered_waypoints + [dest_candidate]
                    city_names = [c.name for c in ordered_cities]

                    total_demanded = sum(c.requested_qty for c in candidates)
                    sell_qty = min(total_demanded, req.available_qty)
                    revenue = sell_qty * req.price_per_kg
                    travel_cost = total_hours * req.cost_per_hour
                    profit = revenue - travel_cost

                    all_routes.append({
                        "ordered_stops": city_names,
                        "total_travel_hours": total_hours,
                        "total_distance_km": total_km,
                        "expected_sell_qty_kg": sell_qty,
                        "expected_revenue_bgn": revenue,
                        "estimated_travel_cost_bgn": travel_cost,
                        "estimated_profit_bgn": profit,
                        "is_profitable": profit > 0,
                    })

        # Sort all discovered routes by quickest time (hours)
        all_routes.sort(key=lambda x: x["total_travel_hours"])
        
        # Take up to top 3 and round out properties
        for idx, r in enumerate(all_routes[:3]):
            route_name = "Quickest Route" if idx == 0 else f"Option {idx + 1}"
            r["option_id"] = idx + 1
            r["name"] = route_name
            r["total_travel_hours"] = round(r["total_travel_hours"], 2)
            r["total_distance_km"] = round(r["total_distance_km"], 2)
            r["expected_sell_qty_kg"] = round(r["expected_sell_qty_kg"], 1)
            r["expected_revenue_bgn"] = round(r["expected_revenue_bgn"], 2)
            r["estimated_travel_cost_bgn"] = round(r["estimated_travel_cost_bgn"], 2)
            r["estimated_profit_bgn"] = round(r["estimated_profit_bgn"], 2)
            
            options.append(r)
            
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Could not calculate routes: {str(e)}")
    
    if not options:
        raise HTTPException(status_code=502, detail="No routes returned from Google Maps API - check that API key is valid and Directions API is enabled")

    return {
        "options": options,
        "best_option": max(options, key=lambda x: x["estimated_profit_bgn"])["option_id"],
        "message": f"{len(options)} route option(s) generated. Choose the best for your needs."
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, port=8000, reload=True)
    # import sys, json, asyncio
    
    # if len(sys.argv) > 1:
    #     file_path = sys.argv[1]
    #     print(f"Reading input from {file_path}...\n")
        
    #     try:
    #         with open(file_path, "r", encoding="utf-8") as f:
    #             data = json.load(f)
                
    #         req = RouteRequest(**data)
            
    #         async def run_cli():
    #             try:
    #                 result = await recommend_route(req)
    #                 print("--- OUTPUT ---")
    #                 print(json.dumps(result, indent=2, ensure_ascii=False))
    #             except HTTPException as e:
    #                 print(f"API Error: {e.detail}")
    #             except Exception as e:
    #                 print(f"Error computing route: {e}")
            
    #         asyncio.run(run_cli())
            
    #     except FileNotFoundError:
    #         print(f"Error: File '{file_path}' not found.")
    #     except Exception as e:
    #         print(f"Error parsing input: {e}")
    # else:
    #     print("Usage: python main.py <path_to_json_file>\nExample: python main.py input.json")
