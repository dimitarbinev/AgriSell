import statistics
import firebase_admin
from firebase_admin import credentials, firestore
import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict, List, Literal, Optional
from pydantic import BaseModel, Field
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
import os
import asyncio
from dotenv import load_dotenv
import pandas as pd
from contextlib import asynccontextmanager
import logging

load_dotenv()

# -------------------------------------------------------
# Firebase setup
# -------------------------------------------------------
# Global instance
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


class CityModel(BaseModel):
    name: str
    lat: float
    lng: float
    requested_qty: float

class ProduceClassification(BaseModel):
    item: str = Field(description="Името на продукта на български")
    category: Literal['Зеленчуци', 'Плодове', 'Зърнени', 'Млечни', 'Билки', 'Ядки', 'Мед', 'Месо', 'Яйца', 'Други'] = Field(
        description="Категорията, към която принадлежи продукта"
    )
    confidence: float = Field(description="Увереност на модела от 0 до 1")

class ClassificationRequest(BaseModel):
    product_name: str

class PriceSuggestionRequest(BaseModel):
    product_name: str
    season: Optional[str] = None  # 'Пролет', 'Лято', 'Есен', 'Зима', 'Целогодишно'

class DbRouteRequest(BaseModel):
    seller_id: str
    listing_id: str
    product_id: str
    cost_per_hour: float = 15.0

# -------------------------------------------------------
# Excel — NSI Agricultural Price Data
# -------------------------------------------------------

EXCEL_PATH = os.path.join(
    os.path.dirname(__file__),
    "Prices_of_agricultural_products_by_year.xlsx"
)

# Season → quarter column in Excel
SEASON_TO_QUARTER: Dict[str, Optional[str]] = {
    "Пролет": "Q2",         # April–June
    "Лято":   "Q3",         # July–September
    "Есен":   "Q4",         # October–December
    "Зима":   "Q1",         # January–March
    "Целогодишно": None,    # use overall average
}

# Cached dataframe & product list
_excel_df: Optional[pd.DataFrame] = None
_excel_products: Optional[List[str]] = None

def _get_excel_data() -> tuple[Optional[pd.DataFrame], Optional[List[str]]]:
    """Load & cache the Excel. Returns (df, product_names)."""
    global _excel_df, _excel_products
    if _excel_df is not None:
        return _excel_df, _excel_products
    if not os.path.exists(EXCEL_PATH):
        return None, None
    try:
        # Row 0 = title, Row 1 = merged header, Row 2 = quarter labels → skip 3 rows
        df = pd.read_excel(EXCEL_PATH, header=None, skiprows=3)
        # Actual columns after skipping:
        # 0=Код  1=Показател  2=Мерна ед.  3=Q1  4=Q2  5=Q3  6=Q4  7=Annual
        df.columns = ["code", "name", "unit", "Q1", "Q2", "Q3", "Q4", "annual"]
        df = df.dropna(subset=["name"])
        df = df[df["name"].astype(str).str.strip() != ""]
        df = df.reset_index(drop=True)
        _excel_df = df
        _excel_products = df["name"].tolist()
        return _excel_df, _excel_products
    except Exception as e:
        print(f"Excel load error: {e}")
        return None, None

def _norm(s: str) -> str:
    return str(s).lower().strip()

def _find_product_simple(products: List[str], needle: str) -> Optional[int]:
    """
    Substring match — returns the index of the row with the most quarterly data.
    Prefers rows with more non-missing Q1-Q4 values over the first match.
    """
    n = _norm(needle)
    matches = []
    for i, p in enumerate(products):
        if n in _norm(p):
            matches.append(i)

    if not matches:
        return None
    if len(matches) == 1:
        return matches[0]

    # Multiple matches — prefer the one with the most quarterly data
    df, _ = _get_excel_data()
    if df is None:
        return matches[0]

    best_idx = matches[0]
    best_count = 0
    for i in matches:
        row = df.iloc[i]
        count = sum(
            1 for q in ["Q1", "Q2", "Q3", "Q4"]
            if str(row[q]) not in ("-", "nan", "") and row[q] is not None
        )
        if count > best_count:
            best_count = count
            best_idx = i

    return best_idx

async def _find_product_openai(products: List[str], needle: str) -> Optional[int]:
    """Ask GPT-4o-mini to pick the best matching product index."""
    if not os.getenv("OPENAI_API_KEY"):
        return None
    try:
        numbered = "\n".join(f"{i}. {p}" for i, p in enumerate(products))
        from langchain_openai import ChatOpenAI as _LLM
        _llm = _LLM(model="gpt-4o-mini", temperature=0)
        prompt = (
            f"Имаш списък от официални статистически показатели на селскостопански продукти (на български).\n"
            f"Намери индекса на показателя, който НАЙ-ДОБРЕ съответства на: \"{needle}\"\n"
            f"(Забележка: Входът може да е на латиница/транслитерация или синоним).\n\n"
            f"{numbered}\n\n"
            "Отговори САМО с числото (индекса). Ако няма подходящ отговори с -1."
        )
        result = await _llm.ainvoke(prompt)
        idx = int(result.content.strip())
        if 0 <= idx < len(products):
            return idx
    except Exception as e:
        print(f"OpenAI matching error: {e}")
    return None

EUR_TO_BGN = 1.95583  # Фиксиран курс БНБ

def _to_per_kg(value, unit: str) -> Optional[float]:
    """Convert raw Excel value to €/кг based on unit."""
    try:
        v = float(value)
        if v <= 0:
            return None
    except (ValueError, TypeError):
        return None
    u = str(unit).strip().lower()
    if u == "т":
        return round(v / 1000, 4)   # €/тон → €/кг
    elif u in ("кг", "kg"):
        return round(v, 4)           # already per кг
    elif u == "хил.л":
        return round(v / 1000, 4)   # €/хил.л → €/л
    else:
        return round(v, 4)           # бр, etc. — return raw

def _eur_bgn(eur: float) -> float:
    """Convert € to лв."""
    return round(eur * EUR_TO_BGN, 2)

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
        custom_instructions = ["Доматът е зеленчук."]
        llm = ChatOpenAI(model="gpt-4o-mini", temperature=0).with_structured_output(ProduceClassification)
        prompt = ChatPromptTemplate.from_messages([
            ("system", f"Ти си експерт по хранителни стоки. Твоята задача е да класифицираш продукти на български език в правилни категории. Следвай следните инструкции: {",".join(custom_instructions)}"),
            ("human", "Класифицирай следния продукт: {product}")
        ])
        classification_chain = prompt | llm
    except Exception as e:
        print(f"Error initializing OpenAI: {e}")

# -------------------------------------------------------
# Endpoints
# -------------------------------------------------------

@app.post("/price-suggestion")
async def price_suggestion(req: PriceSuggestionRequest):
    """
    Търси продукта в NSI Excel файла и връща препоръчана цена на кг.
    Input:  { product_name: 'Домати', season: 'Лято' }
    Output: { product, quarterly_prices, overall_average, season_average, suggested_price }
    """
    df, products = _get_excel_data()
    if df is None:
        raise HTTPException(
            status_code=503,
            detail="Excel файлът с цени не е намерен на сървъра."
        )

    # 1. Simple substring match first (fast & free)
    idx = _find_product_simple(products, req.product_name)

    # 2. OpenAI fallback for Bulgarian morphology / synonyms
    if idx is None:
        idx = await _find_product_openai(products, req.product_name)

    if idx is None:
        raise HTTPException(
            status_code=404,
            detail=f"Продуктът '{req.product_name}' не е намерен в базата с цени."
        )

    row  = df.iloc[idx]
    unit = str(row["unit"])

    # 3. Build quarterly prices in €/кг
    quarterly_eur: Dict[str, float] = {}
    for q in ["Q1", "Q2", "Q3", "Q4"]:
        raw = row[q]
        if str(raw) not in ("-", "nan", "") and raw is not None:
            pkg = _to_per_kg(raw, unit)
            if pkg is not None:
                quarterly_eur[q] = pkg

    if not quarterly_eur:
        raise HTTPException(
            status_code=422,
            detail="Не можахме да извлечем тримесечни цени за намерения продукт."
        )

    # Convert all quarters to BGN
    quarterly_bgn = {q: _eur_bgn(v) for q, v in quarterly_eur.items()}

    vals_eur = list(quarterly_eur.values())
    
    # 4. Overall / Annual Average
    # We prefer the pre-calculated 'annual' column from Excel if available
    raw_annual = row.get("annual")
    annual_pkg = _to_per_kg(raw_annual, unit) if raw_annual is not None else None
    
    if annual_pkg is not None:
        overall_avg_eur = annual_pkg
    else:
        # Fallback to simple mean if annual col is empty
        overall_avg_eur = round(sum(vals_eur) / len(vals_eur), 4)
        
    overall_avg_bgn = _eur_bgn(overall_avg_eur)

    # 4. Season-specific price
    season_eur: Optional[float] = None
    season_bgn: Optional[float] = None
    if req.season:
        quarter = SEASON_TO_QUARTER.get(req.season)
        if quarter:
            season_eur = quarterly_eur.get(quarter)
            season_bgn = quarterly_bgn.get(quarter)
        else:                    # Целогодишно → overall avg
            season_eur = overall_avg_eur
            season_bgn = overall_avg_bgn

    suggested_eur = season_eur if season_eur is not None else overall_avg_eur
    suggested_bgn = season_bgn if season_bgn is not None else overall_avg_bgn

    return {
        "product":              row["name"],
        "unit":                 unit,
        # Тримесечни цени
        "quarterly_eur":        quarterly_eur,   # €/кг
        "quarterly_bgn":        quarterly_bgn,   # лв/кг
        # Годишна средна
        "overall_average_eur":  overall_avg_eur,
        "overall_average_bgn":  overall_avg_bgn,
        # Сезонна средна (None ако няма избран сезон)
        "season_average_eur":   season_eur,
        "season_average_bgn":   season_bgn,
        # Препоръчана цена (сезонна ако е избран сезон, иначе годишна)
        "suggested_price_eur":  round(suggested_eur, 2),
        "suggested_price_bgn":  round(suggested_bgn, 2),
        "season":               req.season,
    }


@app.post("/classify-product")
async def classify_product(req: ClassificationRequest):
    if not classification_chain:
        # Fallback logic if OpenAI is not configured
        name = req.product_name.lower()
        if "домат" in name or "краставиц" in name:
            return {"item": req.product_name, "category": "Зеленчуци", "confidence": 1.0}
        return {"item": req.product_name, "category": "Други", "confidence": 0.0}
    
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

            # Build Routes API request body
            body = {
                "origin": {
                    "location": {
                        "latLng": {"latitude": seller_coords['lat'], "longitude": seller_coords['lng']}
                    }
                },
                "destination": {
                    "location": {
                        "latLng": {"latitude": dest.lat, "longitude": dest.lng}
                    }
                },
                "travelMode": "DRIVE",
                "polylineEncoding": "ENCODED_POLYLINE",
                "computeAlternativeRoutes": False,
                "routingPreference": "TRAFFIC_AWARE",
                "languageCode": "bg",
                "units": "METRIC",
            }

            if wps:
                body["intermediates"] = [
                    {"location": {"latLng": {"latitude": c.lat, "longitude": c.lng}}}
                    for c in wps
                ]
                body["optimizeWaypointOrder"] = True

            url = "https://routes.googleapis.com/directions/v2:computeRoutes"
            headers = {
                "Content-Type": "application/json",
                "X-Goog-Api-Key": MAPS_KEY,
                "X-Goog-FieldMask": "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.optimizedIntermediateWaypointIndex,routes.legs.duration,routes.legs.distanceMeters",
            }

            async with httpx.AsyncClient() as client:
                r = await client.post(url, json=body, headers=headers)
                data = r.json()
                
                if "routes" in data and len(data["routes"]) > 0:
                    route = data["routes"][0]

                    # Duration comes as "1234s" string
                    duration_str = route.get("duration", "0s")
                    total_secs = int(duration_str.rstrip("s"))
                    total_hrs = total_secs / 3600

                    total_km = route.get("distanceMeters", 0) / 1000

                    # Encoded polyline for drawing on the map
                    encoded_polyline = route.get("polyline", {}).get("encodedPolyline", "")

                    # Optimized waypoint order
                    order = route.get("optimizedIntermediateWaypointIndex", [])
                    stops = [seller_city_name]
                    if order:
                        for idx in order:
                            stops.append(wps[idx].name)
                    else:
                        for c in wps:
                            stops.append(c.name)
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
                        "is_profitable": profit > 0,
                        "encoded_polyline": encoded_polyline,
                    }
                print(f"Routes API error for {label}: {data}")
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

    # Ensure CORS is always added (it was lost in replacement)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
