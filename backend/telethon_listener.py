from telethon import TelegramClient, events
from telethon.tl.types import InputPeerChannel
import os, asyncio, httpx
from dotenv import load_dotenv

load_dotenv()

api_id = int(os.environ['TELEGRAM_API_ID'])
api_hash = os.environ['TELEGRAM_API_HASH']
channel_id = int(os.environ['TELEGRAM_CHANNEL_ID'])
channel_hash = int(os.environ['TELEGRAM_CHANNEL_HASH'])
server = os.environ.get('BACKEND_URL', 'http://127.0.0.1:8000')

client = TelegramClient('session', api_id, api_hash)
channel = InputPeerChannel(channel_id, channel_hash)

@client.on(events.NewMessage(chats=channel))
async def handler(event):
    text = event.raw_text
    print(f"[DEBUG] New message received: {text!r}")
    async with httpx.AsyncClient(timeout=10) as c:
        try:
            print(f"[DEBUG] Sending message to backend: {server}/ingest")
            resp = await c.post(f'{server}/ingest', json={'text': text})
            print(f"[DEBUG] Backend response status: {resp.status_code}")
        except Exception as e:
            print(f"[ERROR] Failed to send message to backend: {e}")

async def main():
    print("[DEBUG] Starting Telegram client...")
    await client.start()
    print("[DEBUG] Client started. Listening for new messages...")
    await client.run_until_disconnected()

asyncio.run(main())
