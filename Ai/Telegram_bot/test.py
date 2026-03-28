import logging
import firebase_admin
from firebase_admin import credentials, firestore
from telegram import Update, ReplyKeyboardMarkup, KeyboardButton
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    MessageHandler,
    ContextTypes,
    filters,
    ConversationHandler,
    CallbackQueryHandler,
)
import os
import asyncio
from dotenv import load_dotenv

load_dotenv()

# ----------------- Logging -----------------
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)

# ----------------- Firebase -----------------
import json
if not firebase_admin._apps:
    # Build robust path to JSON file
    current_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.join(current_dir, "hacktues12-firebase-adminsdk-fbsvc-7ce9f543c1.json")
    
    with open(json_path, "r") as f:
        service_account_info = json.load(f)

    # Inject sensitive keys from .env
    service_account_info["private_key_id"] = os.getenv("PRIVATE_KEY_ID")
    service_account_info["private_key"] = os.getenv("PRIVATE_KEY").replace("\\n", "\n") if os.getenv("PRIVATE_KEY") else None

    cred = credentials.Certificate(service_account_info)
    firebase_admin.initialize_app(cred)
else:
    # Use existing app
    pass

db = firestore.client()

BOT_TOKEN = os.getenv("BOT_KEY_TOKEN")

if not BOT_TOKEN:
    print("❌ ERROR: BOT_KEY_TOKEN not found in .env!")
    exit(1)

# ----------------- Conversation states -----------------
PHONE, CHOICE, PRODUCT_SELECT, RESERVATION_LIST, RESERVATION_DETAIL = range(5)

# ----------------- /start -----------------
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    keyboard = ReplyKeyboardMarkup(
        [[KeyboardButton("Share phone", request_contact=True)]],
        resize_keyboard=True,
        one_time_keyboard=True
    )
    await update.message.reply_text(
        "Connected! Please share your phone number to start:",
        reply_markup=keyboard
    )
    return PHONE

# ----------------- Handle phone -----------------
async def handle_contact(update: Update, context: ContextTypes.DEFAULT_TYPE):
    # Get phone from contact or text
    if update.message.contact:
        phone = update.message.contact.phone_number
    else:
        phone = update.message.text

    # Basic cleanup: keep only digits
    phone_digits = "".join(filter(str.isdigit, phone))
    
    # Normalize Bulgarian international/local formats
    if phone_digits.startswith("359"):
        phone_clean = "0" + phone_digits[3:]
    elif len(phone_digits) == 9 and not phone_digits.startswith("0"):
        phone_clean = "0" + phone_digits
    else:
        phone_clean = phone_digits

    context.user_data["phone"] = phone_clean

    # --- Save Chat ID to Firestore ---
    try:
        users_ref = db.collection("users")
        intl_phone_359 = "359" + phone_clean[1:] if phone_clean.startswith("0") else phone_clean
        intl_phone_plus = "+359" + phone_clean[1:] if phone_clean.startswith("0") else ("+" + phone_clean if not phone_clean.startswith("+") else phone_clean)
        
        # All variations to try
        lookups = [
            ("phoneNumber", phone_clean),
            ("phoneNumber", intl_phone_359),
            ("phoneNumber", intl_phone_plus),
            ("phone", phone_clean),
            ("phone", intl_phone_359),
            ("phone", intl_phone_plus),
            ("phoneNumber", phone),
            ("phone", phone)
        ]
        
        found_doc = None
        for field, value in lookups:
            if not value: continue
            docs = users_ref.where(field, "==", value).limit(1).get()
            if docs:
                found_doc = docs[0]
                break
        
        if found_doc:
            user_doc_id = found_doc.id
            context.user_data["user_doc_id"] = user_doc_id
            users_ref.document(user_doc_id).update({"telegramChatId": update.effective_chat.id})
            logging.info(f"Updated telegramChatId for user {user_doc_id}")
        else:
            logging.warning(f"Registration: User NOT found in Firestore for any variations: {[v for f, v in lookups]}")
    except Exception as e:
        logging.error(f"Error saving chat_id: {e}")

    # Show list of phone formats we tried if not found
    search_info = f"\n(Searched for: {phone_clean})"
    
    if found_doc:
        # Ask to see products or reservations
        keyboard = ReplyKeyboardMarkup(
            [["View My Products", "View My Reservations"]],
            resize_keyboard=True
        )
        await update.message.reply_text(
            f"Phone received! Choose an option:{search_info}",
            reply_markup=keyboard
        )
    else:
        await update.message.reply_text(
            f"Phone received, but no user found in the database with that number.{search_info}\nPlease make sure you are registered in the mobile app with this exact format."
        )
    return CHOICE

# ----------------- Handle choice -----------------
async def handle_choice(update: Update, context: ContextTypes.DEFAULT_TYPE):
    choice = update.message.text
    context.user_data["choice"] = choice
    user_doc_id = context.user_data.get("user_doc_id")
    
    if not user_doc_id:
        # Fallback: Try to find user again if session lost
        phone = context.user_data.get("phone")
        if not phone:
            await update.message.reply_text("Session lost. Please /start again.")
            return ConversationHandler.END
            
        users_ref = db.collection("users")
        # Reuse robust lookup logic
        lookups = [
            ("phone", phone),
            ("phoneNumber", phone),
            ("phone", "359" + phone[1:] if phone.startswith("0") else phone),
            ("phoneNumber", "359" + phone[1:] if phone.startswith("0") else phone),
            ("phone", "+359" + phone[1:] if phone.startswith("0") else phone),
            ("phoneNumber", "+359" + phone[1:] if phone.startswith("0") else phone),
        ]
        
        for field, value in lookups:
            docs = users_ref.where(field, "==", value).limit(1).get()
            if docs:
                user_doc_id = docs[0].id
                context.user_data["user_doc_id"] = user_doc_id
                break

    if not user_doc_id:
        await update.message.reply_text("No user found with this phone number. Please ensure you are registered.")
        return ConversationHandler.END

    if choice == "View My Products":
        # Fetch products from subcollection
        products_ref = db.collection("users").document(user_doc_id).collection("products")
        products_docs = list(products_ref.stream())
        if not products_docs:
            await update.message.reply_text("You have no products.")
            return CHOICE

        product_map = {}
        for i, doc in enumerate(products_docs):
            p_data = doc.to_dict()
            p_name = p_data.get("productName") or f"Product {i+1}"
            product_map[p_name] = p_data
        
        context.user_data["product_map"] = product_map
        buttons = [[name] for name in product_map.keys()]
        buttons.append(["Back to Menu"])
        keyboard = ReplyKeyboardMarkup(buttons, resize_keyboard=True)
        await update.message.reply_text("Select a product:", reply_markup=keyboard)
        return PRODUCT_SELECT
    
    elif choice == "View My Reservations":
        # Fetch pending reservations where sellerId == user_doc_id
        res_ref = db.collection("reservations").where("sellerId", "==", user_doc_id).where("status", "==", "pending")
        res_docs = list(res_ref.stream())
        
        if not res_docs:
            await update.message.reply_text("You have no pending reservations.")
            return CHOICE

        res_map = {}
        buttons = []
        for doc in res_docs:
            data = doc.to_dict()
            res_id = doc.id
            label = f"{data.get('productName', 'Product')} - {data.get('quantity', 0)}kg ({data.get('buyerName', 'Anonymous')})"
            res_map[label] = {"id": res_id, "data": data}
            buttons.append([label])
        
        context.user_data["res_map"] = res_map
        buttons.append(["Back to Menu"])
        keyboard = ReplyKeyboardMarkup(buttons, resize_keyboard=True)
        await update.message.reply_text("Select a reservation to manage:", reply_markup=keyboard)
        return RESERVATION_LIST

    else:
        # Re-show menu if something else was typed
        keyboard = ReplyKeyboardMarkup([["View My Products", "View My Reservations"]], resize_keyboard=True)
        await update.message.reply_text("Please choose an option:", reply_markup=keyboard)
        return CHOICE

# ----------------- Handle product selection -----------------
async def handle_product_select(update: Update, context: ContextTypes.DEFAULT_TYPE):
    selected_name = update.message.text
    
    if selected_name == "Back to Menu":
        keyboard = ReplyKeyboardMarkup(
            [["View My Products", "View My Reservations"]],
            resize_keyboard=True
        )
        await update.message.reply_text("Main Menu:", reply_markup=keyboard)
        return CHOICE

    product_map = context.user_data.get("product_map", {})
    product_data = product_map.get(selected_name)

    if not product_data:
        await update.message.reply_text("Please select a product from the list or 'Back to Menu'.")
        return PRODUCT_SELECT
    else:
        # Format product details
        details = "\n".join([f"<b>{k}</b>: {v}" for k, v in product_data.items()])
        await update.message.reply_text(f"<b>{selected_name} Details:</b>\n{details}", parse_mode="HTML")

# ----------------- Handle reservation list -----------------
async def handle_reservation_list(update: Update, context: ContextTypes.DEFAULT_TYPE):
    selected_label = update.message.text
    if selected_label == "Back to Menu":
        keyboard = ReplyKeyboardMarkup([["View My Products", "View My Reservations"]], resize_keyboard=True)
        await update.message.reply_text("Main Menu:", reply_markup=keyboard)
        return CHOICE

    res_map = context.user_data.get("res_map", {})
    selected_res = res_map.get(selected_label)
    if not selected_res:
        await update.message.reply_text("Please select a reservation from the list.")
        return RESERVATION_LIST

    context.user_data["selected_res"] = selected_res
    data = selected_res["data"]
    
    details = (
        f"📦 <b>Product:</b> {data.get('productName')}\n"
        f"⚖️ <b>Quantity:</b> {data.get('quantity')} kg\n"
        f"👤 <b>Buyer:</b> {data.get('buyerName')}\n"
        f"📍 <b>City:</b> {data.get('city')}\n"
        f"💰 <b>Deposit:</b> {data.get('deposit')} BGN\n"
        f"📅 <b>Created:</b> {data.get('createdAt')}"
    )
    
    keyboard = ReplyKeyboardMarkup(
        [["✅ Accept", "❌ Cancel"], ["Back to List"]],
        resize_keyboard=True
    )
    await update.message.reply_text(
        f"<b>Reservation Details:</b>\n\n{details}\n\nWhat would you like to do?",
        reply_markup=keyboard,
        parse_mode="HTML"
    )
    return RESERVATION_DETAIL

# ----------------- Handle reservation action -----------------
async def handle_reservation_action(update: Update, context: ContextTypes.DEFAULT_TYPE):
    action = update.message.text
    res_info = context.user_data.get("selected_res")
    if not res_info: return CHOICE # Safety

    res_id = res_info["id"]
    res_data = res_info["data"]

    if action == "Back to List":
        return await handle_choice(update, context) # Re-runs list logic

    try:
        if action == "✅ Accept":
            db.collection("reservations").document(res_id).update({
                "status": "confirmed",
                "updatedAt": firestore.SERVER_TIMESTAMP
            })
            await update.message.reply_text(f"✅ Reservation for {res_data.get('productName')} accepted!")
            
        elif action == "❌ Cancel":
            # REPLICATE Node Backend cancelReservation logic
            seller_id = res_data.get("sellerId")
            product_id = res_data.get("productId")
            listing_id = res_data.get("listingId")
            quantity = float(res_data.get("quantity", 0))

            # 1. Update reservation status
            db.collection("reservations").document(res_id).update({
                "status": "cancelled",
                "updatedAt": firestore.SERVER_TIMESTAMP
            })

            # 2. Decrement requestedQuantity on listing
            if seller_id and product_id and listing_id:
                listing_ref = db.collection("users").document(seller_id).collection("products").document(product_id).collection("listings").document(listing_id)
                listing_snap = listing_ref.get()
                if listing_snap.exists:
                    current_qty = float(listing_snap.to_dict().get("requestedQuantity", 0))
                    new_qty = max(0, current_qty - quantity)
                    listing_ref.update({"requestedQuantity": new_qty})

            # 3. Update private order (optional but good for consistency)
            buyer_id = res_data.get("buyerId")
            if buyer_id:
                orders_ref = db.collection("users").document(buyer_id).collection("orders")
                order_query = orders_ref.where("listingId", "==", listing_id).where("quantity", "==", quantity).limit(1).get()
                if order_query:
                    order_query[0].reference.update({"status": 3})

            await update.message.reply_text(f"❌ Reservation for {res_data.get('productName')} cancelled.")

    except Exception as e:
        await update.message.reply_text(f"⚠️ Error performing action: {str(e)}")
        logging.error(f"Reservation action error: {e}")

    # Go back to menu
    keyboard = ReplyKeyboardMarkup([["View My Products", "View My Reservations"]], resize_keyboard=True)
    await update.message.reply_text("Main Menu:", reply_markup=keyboard)
    return CHOICE

# ----------------- Cancel -----------------
async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("Chat ended.")
    return ConversationHandler.END

# ----------------- Handle inline buttons -----------------
async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    
    data = query.data
    # data format: "accept_RESID" or "cancel_RESID"
    action, res_id = data.split("_", 1)

    # 1. Fetch reservation data
    res_ref = db.collection("reservations").document(res_id)
    res_snap = res_ref.get()
    
    if not res_snap.exists:
        await query.edit_message_text("⚠️ Reservation no longer exists.")
        return

    res_data = res_snap.to_dict()
    product_name = res_data.get("productName", "Product")

    try:
        if action == "accept":
            res_ref.update({
                "status": "confirmed",
                "updatedAt": firestore.SERVER_TIMESTAMP
            })
            await query.edit_message_text(f"✅ <b>Accepted:</b> {product_name} reservation acknowledged.", parse_mode="HTML")
            
        elif action == "cancel":
            # Replicate full cancellation logic
            seller_id = res_data.get("sellerId")
            product_id = res_data.get("productId")
            listing_id = res_data.get("listingId")
            quantity = float(res_data.get("quantity", 0))

            res_ref.update({
                "status": "cancelled",
                "updatedAt": firestore.SERVER_TIMESTAMP
            })

            # Update listing quantity
            if seller_id and product_id and listing_id:
                listing_ref = db.collection("users").document(seller_id).collection("products").document(product_id).collection("listings").document(listing_id)
                l_snap = listing_ref.get()
                if l_snap.exists:
                    new_qty = max(0, float(l_snap.to_dict().get("requestedQuantity", 0)) - quantity)
                    listing_ref.update({"requestedQuantity": new_qty})

            # Update order status
            buyer_id = res_data.get("buyerId")
            if buyer_id:
                order_query = db.collection("users").document(buyer_id).collection("orders").where("listingId", "==", listing_id).where("quantity", "==", quantity).limit(1).get()
                if order_query:
                    order_query[0].reference.update({"status": 3})

            await query.edit_message_text(f"❌ <b>Cancelled:</b> {product_name} reservation has been removed.", parse_mode="HTML")

    except Exception as e:
        logging.error(f"Error in handle_callback: {e}")
        await query.message.reply_text(f"⚠️ Error: {str(e)}")

# ----------------- Main -----------------
def create_application():
    app = ApplicationBuilder().token(BOT_TOKEN).build()
    
    # Handle inline buttons (Accept/Cancel)
    app.add_handler(CallbackQueryHandler(handle_callback))

    conv_handler = ConversationHandler(
        entry_points=[CommandHandler("start", start)],
        states={
            PHONE: [
                MessageHandler(filters.CONTACT, handle_contact),
                MessageHandler(filters.TEXT & ~filters.COMMAND, handle_contact)
            ],
            CHOICE: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_choice)],
            PRODUCT_SELECT: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_product_select)],
            RESERVATION_LIST: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_reservation_list)],
            RESERVATION_DETAIL: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_reservation_action)],
        },
        fallbacks=[CommandHandler("cancel", cancel)],
    )

    app.add_handler(conv_handler)
    return app

async def run_bot():
    app = create_application()
    async with app:
        await app.initialize()
        await app.start()
        await app.updater.start_polling()
        print("🚀 Bot is running...")
        # Keep it running until cancelled
        while True:
            await asyncio.sleep(1)

def main():
    app = create_application()
    print("🚀 Bot is running (standalone)...")
    app.run_polling()

if __name__ == "__main__":
    main()