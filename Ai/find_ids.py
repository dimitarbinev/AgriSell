import firebase_admin
from firebase_admin import credentials, firestore
import json
import os
from dotenv import load_dotenv

load_dotenv()

json_path = 'Telegram_bot/hacktues12-firebase-adminsdk-fbsvc-7ce9f543c1.json'
with open(json_path) as f:
    info = json.load(f)

pk_id = os.getenv("PRIVATE_KEY_ID")
pk = os.getenv("PRIVATE_KEY")
if pk_id: info["private_key_id"] = pk_id
if pk: info["private_key"] = pk.replace("\\n", "\n")

cred = credentials.Certificate(info)
firebase_admin.initialize_app(cred)
db = firestore.client()

f = open("valid_ids.txt", "w")

# Find reservations first
res_docs = db.collection('reservations').limit(10).stream()
for r in res_docs:
    d = r.to_dict()
    if d.get('listingId') and d.get('sellerId') and d.get('productId'):
        f.write(f"LID: {d.get('listingId')}\n")
        f.write(f"SID: {d.get('sellerId')}\n")
        f.write(f"PID: {d.get('productId')}\n")
        f.write("---\n")

# If no reservations with IDs, try Any Listing
sellers = list(db.collection('users').where('role', '==', 'seller').limit(10).stream())
for s in sellers:
    prods = list(db.collection('users').document(s.id).collection('products').limit(3).stream())
    for p in prods:
        ls = list(db.collection('users').document(s.id).collection('products').document(p.id).collection('listings').limit(1).stream())
        for l in ls:
            f.write(f"LID: {l.id}\n")
            f.write(f"SID: {s.id}\n")
            f.write(f"PID: {p.id}\n")
            f.write("---\n")
f.close()
print("DONE. Check valid_ids.txt")
