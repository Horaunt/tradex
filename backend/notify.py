import os
import firebase_admin
from firebase_admin import credentials, messaging
from dotenv import load_dotenv

load_dotenv()  # load your .env

cred_path = os.environ.get("FIREBASE_CRED_PATH")
if not cred_path or not os.path.isfile(cred_path):
    raise ValueError(f"Invalid Firebase credential path: {cred_path}")

cred = credentials.Certificate(cred_path)
firebase_admin.initialize_app(cred)

def push_fcm(topic: str, payload: dict):
    """Send FCM push notification to a topic."""
    message = messaging.Message(
        data=payload,
        topic=topic,
        notification=messaging.Notification(
            title=payload.get("title", "Trade Alert"),
            body=payload.get("body", "")
        ),
    )
    response = messaging.send(message)
    return response
