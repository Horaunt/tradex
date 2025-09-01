from kiteconnect import KiteConnect
from dotenv import load_dotenv
import os

load_dotenv()

Z_API_KEY = os.getenv("Z_API_KEY")
Z_API_SECRET = os.getenv("Z_API_SECRET")
Z_REQUEST_TOKEN = os.getenv("Z_REQUEST_TOKEN")

kite = KiteConnect(api_key=Z_API_KEY)
data = kite.generate_session(Z_REQUEST_TOKEN, api_secret=Z_API_SECRET)
access_token = data["access_token"]
print("Access Token:", access_token)
