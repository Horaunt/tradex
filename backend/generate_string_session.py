from telethon.sync import TelegramClient
from telethon.sessions import StringSession

 # from https://my.telegram.org

with TelegramClient(StringSession(), api_id, api_hash) as client:
    print("Your StringSession is:")
    print(client.session.save())
