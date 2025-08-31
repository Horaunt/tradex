from telethon import TelegramClient
from telethon.tl.types import InputPeerChannel
from dotenv import load_dotenv
import os, asyncio

load_dotenv()

api_id = int(os.environ['TELEGRAM_API_ID'])
api_hash = os.environ['TELEGRAM_API_HASH']
channel_id = int(os.environ['TELEGRAM_CHANNEL_ID'])  # numeric ID
access_hash = int(os.environ['TELEGRAM_CHANNEL_HASH'])  # <-- needed for private channels

client = TelegramClient('session', api_id, api_hash)

async def test_channel():
    await client.start()
    await client.get_dialogs()  # fetch all dialogs first
    try:
        channel = InputPeerChannel(channel_id, access_hash)
        print("Channel ready:", channel)
    except Exception as e:
        print("Failed to resolve channel:", e)

asyncio.run(test_channel())
