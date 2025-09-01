import os
from kiteconnect import KiteConnect
from dotenv import load_dotenv

load_dotenv()
kite = None

def get_kite():
    global kite
    if kite is None:
        kite = KiteConnect(api_key=os.environ['Z_API_KEY'])
        kite.set_access_token(os.environ['Z_ACCESS_TOKEN'])
    return kite

def place_limit_option(tradingsymbol, exchange, price, quantity, side, order_tag=None):
    """
    Places a limit order for options.
    
    Args:
        tradingsymbol: Trading symbol from Zerodha
        exchange: Exchange (e.g., 'NFO')
        price: Limit price
        quantity: FINAL quantity to trade (already calculated: lots * lot_size)
        side: 'BUY' or 'SELL'
        order_tag: Optional tag for the order (e.g., 'MAIN', 'SL', 'TARGET')
    
    Returns:
        order_id: Zerodha order ID
    """
    k = get_kite()
    
    order_type_label = order_tag or "ORDER"
    print(f"[BROKER DEBUG] Placing {order_type_label}:")
    print(f"  - Symbol: {tradingsymbol}")
    print(f"  - Exchange: {exchange}")
    print(f"  - Price: {price}")
    print(f"  - Quantity: {quantity}")
    print(f"  - Side: {side}")
    if order_tag:
        print(f"  - Tag: {order_tag}")
    
    # Convert side to Zerodha format
    tx = k.TRANSACTION_TYPE_BUY if side == 'BUY' else k.TRANSACTION_TYPE_SELL
    
    # Place order with the exact quantity provided
    # DO NOT multiply by lot size here - it's already calculated
    try:
        order_params = {
            'variety': k.VARIETY_REGULAR,
            'exchange': exchange,
            'tradingsymbol': tradingsymbol,
            'transaction_type': tx,
            'quantity': quantity,  # Use exact quantity provided
            'product': k.PRODUCT_MIS,
            'order_type': k.ORDER_TYPE_LIMIT,
            'price': price,
            'validity': k.VALIDITY_DAY
        }
        
        # Add tag if provided
        if order_tag:
            order_params['tag'] = order_tag
            
        order_id = k.place_order(**order_params)
        
        print(f"[BROKER DEBUG] {order_type_label} placed successfully: {order_id}")
        return order_id
        
    except Exception as e:
        print(f"[BROKER ERROR] Failed to place {order_type_label}: {e}")
        print(f"[BROKER ERROR] Order parameters: {order_params}")
        raise e

def place_bracket_orders(tradingsymbol, exchange, entry_price, quantity, side, stoploss=None, target=None):
    """
    Places a main order along with optional stoploss and target orders.
    
    Args:
        tradingsymbol: Trading symbol from Zerodha
        exchange: Exchange (e.g., 'NFO')
        entry_price: Entry price for main order
        quantity: FINAL quantity to trade
        side: 'BUY' or 'SELL' for main order
        stoploss: Optional stoploss price (will place SELL order)
        target: Optional target price (will place SELL order)
    
    Returns:
        dict: Contains main_order_id and optional stoploss_order_id, target_order_id
    """
    result = {}
    
    print(f"[BROKER DEBUG] === PLACING BRACKET ORDERS ===")
    print(f"[BROKER DEBUG] Symbol: {tradingsymbol}, Quantity: {quantity}")
    print(f"[BROKER DEBUG] Entry: {entry_price}, SL: {stoploss}, Target: {target}")
    
    # Place main order
    try:
        main_order_id = place_limit_option(
            tradingsymbol, exchange, entry_price, quantity, side, "MAIN"
        )
        result['main_order_id'] = main_order_id
        print(f"[BROKER DEBUG] Main order placed: {main_order_id}")
        
    except Exception as e:
        print(f"[BROKER ERROR] Failed to place main order: {e}")
        raise e
    
    # Place stoploss order if provided
    if stoploss is not None:
        try:
            sl_order_id = place_limit_option(
                tradingsymbol, exchange, stoploss, quantity, "SELL", "STOPLOSS"
            )
            result['stoploss_order_id'] = sl_order_id
            print(f"[BROKER DEBUG] Stoploss order placed: {sl_order_id}")
            
        except Exception as e:
            print(f"[BROKER ERROR] Failed to place stoploss order: {e}")
            result['stoploss_error'] = str(e)
    
    # Place target order if provided
    if target is not None:
        try:
            target_order_id = place_limit_option(
                tradingsymbol, exchange, target, quantity, "SELL", "TARGET"
            )
            result['target_order_id'] = target_order_id
            print(f"[BROKER DEBUG] Target order placed: {target_order_id}")
            
        except Exception as e:
            print(f"[BROKER ERROR] Failed to place target order: {e}")
            result['target_error'] = str(e)
    
    print(f"[BROKER DEBUG] === BRACKET ORDERS COMPLETE ===")
    return result