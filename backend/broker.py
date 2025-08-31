import os
from kiteconnect import KiteConnect
from dotenv import load_dotenv
load_dotenv()
kite=None
def get_kite():
    global kite
    if kite is None:
        kite=KiteConnect(api_key=os.environ['Z_API_KEY'])
        kite.set_access_token(os.environ['Z_ACCESS_TOKEN'])
    return kite
def place_limit_option(tradingsymbol,exchange,price,lots,side):
    k=get_kite()
    qty=lots*50 if 'NIFTY' in tradingsymbol.upper() else lots*15
    tx=k.TRANSACTION_TYPE_BUY if side=='BUY' else k.TRANSACTION_TYPE_SELL
    ordid=k.place_order(variety=k.VARIETY_REGULAR,exchange=exchange,tradingsymbol=tradingsymbol,transaction_type=tx,quantity=qty,product=k.PRODUCT_MIS,order_type=k.ORDER_TYPE_LIMIT,price=price,validity=k.VALIDITY_DAY)
    return ordid
