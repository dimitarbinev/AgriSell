import firebase_admin
from firebase_admin import credentials, firestore
import json
import os
import requests
from dotenv import load_dotenv

load_dotenv()

# --- 1. Connect to Firestore ---
json_path = 'Telegram_bot/hacktues12-firebase-adminsdk-fbsvc-7ce9f543c1.json'
with open(json_path) as f:
    info = json.load(f)

pk_id = os.getenv("PRIVATE_KEY_ID")
pk = os.getenv("PRIVATE_KEY")
if pk_id: info["private_key_id"] = pk_id
if pk: info["private_key"] = pk.replace("\\n", "\n")

if not firebase_admin._apps:
    cred = credentials.Certificate(info)
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("🔍 Searching for a valid Listing (any seller -> any product -> any listing)...")

# Deep search for a real listing
seller_id = None
product_id = None
listing_id = None

# Get all sellers
sellers_ref = db.collection('users').where('role', '==', 'seller').limit(10).stream()

for s_doc in sellers_ref:
    s_id = s_doc.id
    # Get products
    products_ref = db.collection('users').document(s_id).collection('products').limit(3).stream()
    for p_doc in products_ref:
        p_id = p_doc.id
        # Get listings
        listings_ref = db.collection('users').document(s_id).collection('products').document(p_id).collection('listings').limit(1).stream()
        for l_doc in listings_ref:
            seller_id = s_id
            product_id = p_id
            listing_id = l_doc.id
            break
        if listing_id: break
    if listing_id: break

if not listing_id:
    print("❌ Could not find ANY active listing in the DB (users/{id}/products/{id}/listings/{id}).")
    exit()

print(f"✅ Found Valid Entry:")
print(f"   Seller:  {seller_id}")
print(f"   Product: {product_id}")
print(f"   Listing: {listing_id}")

# --- 2. Build the request ---
payload = {
    "seller_id": seller_id,
    "listing_id": listing_id,
    "product_id": product_id,
    "cost_per_hour": 15.0
}

url = "http://127.0.0.1:8000/recommend-route"

print(f"\n🚀 Sending request to {url}...")
try:
    response = requests.post(url, json=payload)
    print(f"Status Code: {response.status_code}")
    
    if response.status_code == 200:
        print("🎉 SUCCESS!")
        print(json.dumps(response.json(), indent=2, ensure_ascii=False))
    elif response.status_code == 422:
         print(f"⚠️ Validation Error: {response.json()}")
    else:
        print(f"⚠️ API Error: {response.text}")
except Exception as e:
    print(f"❌ Connection Error: {e}")
