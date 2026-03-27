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
)
import os
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
PHONE, CHOICE, PRODUCT_SELECT = range(3)

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
        # Try both formats
        query = users_ref.where("phoneNumber", "==", phone_clean).limit(1).get()
        if not query:
            intl_phone = "+359" + phone_clean[1:] if phone_clean.startswith("0") else phone_clean
            query = users_ref.where("phoneNumber", "==", intl_phone).limit(1).get()
        
        if query:
            user_doc_id = query[0].id
            users_ref.document(user_doc_id).update({"telegramChatId": update.effective_chat.id})
            logging.info(f"Updated telegramChatId for user {user_doc_id}")
    except Exception as e:
        logging.error(f"Error saving chat_id: {e}")

    # Ask to see products (User Details removed)
    keyboard = ReplyKeyboardMarkup(
        [["View My Products"]],
        resize_keyboard=True
    )
    await update.message.reply_text(
        "Phone received! Click below to see your products:",
        reply_markup=keyboard
    )
    return CHOICE

# ----------------- Handle choice -----------------
async def handle_choice(update: Update, context: ContextTypes.DEFAULT_TYPE):
    choice = update.message.text
    context.user_data["choice"] = choice
    phone = context.user_data.get("phone")

    # Get user document by phone
    users_ref = db.collection("users")
    
    # Try normalized local format (088...)
    query = users_ref.where("phoneNumber", "==", phone).limit(1).stream()
    user_doc = None
    for doc in query:
        user_doc = doc
    
    # If not found, try international format (+359...) if it looks like a BG number
    if not user_doc and phone.startswith("0"):
        intl_phone = "+359" + phone[1:]
        query = users_ref.where("phoneNumber", "==", intl_phone).limit(1).stream()
        for doc in query:
            user_doc = doc

    if not user_doc:
        await update.message.reply_text("No user found with this phone number. Please ensure you are registered.")
        return ConversationHandler.END

    context.user_data["user_doc_id"] = user_doc.id
    user_data = user_doc.to_dict()
    context.user_data["user_data"] = user_data

    # (User Details logic removed, going straight to products)
    
    # Fetch products from subcollection
    products_ref = db.collection("users").document(user_doc.id).collection("products")
    products_docs = list(products_ref.stream())
    if not products_docs:
        await update.message.reply_text("You have no products.")
        return CHOICE

    # Store products in user_data with a mapping of display name -> product data
    product_map = {}
    for i, doc in enumerate(products_docs):
        p_data = doc.to_dict()
        p_name = p_data.get("productName") or f"Product {i+1}"
        product_map[p_name] = p_data
    
    context.user_data["product_map"] = product_map
    
    # Show list of product names as buttons, plus a Back button
    buttons = [[name] for name in product_map.keys()]
    buttons.append(["Back to Menu"])
    keyboard = ReplyKeyboardMarkup(buttons, resize_keyboard=True)
    await update.message.reply_text("Select a product:", reply_markup=keyboard)
    return PRODUCT_SELECT

# ----------------- Handle product selection -----------------
async def handle_product_select(update: Update, context: ContextTypes.DEFAULT_TYPE):
    selected_name = update.message.text
    
    if selected_name == "Back to Menu":
        keyboard = ReplyKeyboardMarkup(
            [["View My Products"]],
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

    # Offer to go back to products or menu
    keyboard = ReplyKeyboardMarkup(
        [["View My Products"]],
        resize_keyboard=True
    )
    await update.message.reply_text("What would you like to see next?", reply_markup=keyboard)
    return CHOICE

# ----------------- Cancel -----------------
async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("Chat ended.")
    return ConversationHandler.END

# ----------------- Main -----------------
def create_application():
    app = ApplicationBuilder().token(BOT_TOKEN).build()

    conv_handler = ConversationHandler(
        entry_points=[CommandHandler("start", start)],
        states={
            PHONE: [
                MessageHandler(filters.CONTACT, handle_contact),
                MessageHandler(filters.TEXT & ~filters.COMMAND, handle_contact)
            ],
            CHOICE: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_choice)],
            PRODUCT_SELECT: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_product_select)],
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