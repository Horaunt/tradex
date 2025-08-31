from telethon import TelegramClient
from dotenv import load_dotenv
import os

load_dotenv()

api_id = int(os.environ['TELEGRAM_API_ID'])
api_hash = os.environ['TELEGRAM_API_HASH']

client = TelegramClient('session', api_id, api_hash)

async def main():
    await client.start()
    async for dialog in client.iter_dialogs():
        name = dialog.name
        id_ = dialog.id
        access_hash = getattr(dialog.entity, 'access_hash', None)
        print(f"Name: {name}, ID: {id_}, Access Hash: {access_hash}")

with client:
    client.loop.run_until_complete(main())
