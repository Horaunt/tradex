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
    
    # Determine order type based on tag
    if order_tag == "STOPLOSS":
        # For stoploss orders, use SL (Stop Loss) order type
        order_type = k.ORDER_TYPE_SL
        trigger_price = price
        limit_price = price  # Same as trigger price for SL orders
        print(f"  - Order Type: STOP LOSS")
        print(f"  - Trigger Price: {trigger_price}")
        print(f"  - Limit Price: {limit_price}")
    else:
        # For main entry and target orders, use LIMIT order type
        order_type = k.ORDER_TYPE_LIMIT
        trigger_price = 0
        limit_price = price
        print(f"  - Order Type: LIMIT")
        print(f"  - Limit Price: {limit_price}")
    
    # Place order with the exact quantity provided
    try:
        order_params = {
            'variety': k.VARIETY_REGULAR,
            'exchange': exchange,
            'tradingsymbol': tradingsymbol,
            'transaction_type': tx,
            'quantity': quantity,
            'product': k.PRODUCT_MIS,
            'order_type': order_type,
            'price': limit_price,
            'validity': k.VALIDITY_DAY
        }
        
        # Add trigger price for stop loss orders
        if order_tag == "STOPLOSS":
            order_params['trigger_price'] = trigger_price
        
        # Add tag if provided
        if order_tag:
            order_params['tag'] = order_tag
            
        print(f"[BROKER DEBUG] Final order parameters: {order_params}")
        
        order_id = k.place_order(**order_params)
        
        print(f"[BROKER DEBUG] {order_type_label} placed successfully: {order_id}")
        return order_id
        
    except Exception as e:
        print(f"[BROKER ERROR] Failed to place {order_type_label}: {e}")
        print(f"[BROKER ERROR] Order parameters were: {order_params}")
        raise e

def place_stoploss_order(tradingsymbol, exchange, trigger_price, quantity, side="SELL", order_tag="STOPLOSS"):
    """
    Places a stop-loss order specifically.
    
    Args:
        tradingsymbol: Trading symbol from Zerodha
        exchange: Exchange (e.g., 'NFO')
        trigger_price: Price at which stop loss should trigger
        quantity: FINAL quantity to trade
        side: Usually 'SELL' for stop loss
        order_tag: Tag for the order
    
    Returns:
        order_id: Zerodha order ID
    """
    k = get_kite()
    
    print(f"[BROKER DEBUG] Placing STOP LOSS ORDER:")
    print(f"  - Symbol: {tradingsymbol}")
    print(f"  - Exchange: {exchange}")
    print(f"  - Trigger Price: {trigger_price}")
    print(f"  - Quantity: {quantity}")
    print(f"  - Side: {side}")
    print(f"  - Tag: {order_tag}")
    
    # Convert side to Zerodha format
    tx = k.TRANSACTION_TYPE_BUY if side == 'BUY' else k.TRANSACTION_TYPE_SELL
    
    try:
        order_params = {
            'variety': k.VARIETY_REGULAR,
            'exchange': exchange,
            'tradingsymbol': tradingsymbol,
            'transaction_type': tx,
            'quantity': quantity,
            'product': k.PRODUCT_MIS,
            'order_type': k.ORDER_TYPE_SL,  # Stop Loss order
            'price': trigger_price,  # Limit price same as trigger for SL
            'trigger_price': trigger_price,  # Trigger price
            'validity': k.VALIDITY_DAY,
            'tag': order_tag
        }
        
        print(f"[BROKER DEBUG] SL order parameters: {order_params}")
        
        order_id = k.place_order(**order_params)
        
        print(f"[BROKER DEBUG] Stop Loss order placed successfully: {order_id}")
        return order_id
        
    except Exception as e:
        print(f"[BROKER ERROR] Failed to place stop loss order: {e}")
        print(f"[BROKER ERROR] SL order parameters were: {order_params}")
        raise e

def place_target_order(tradingsymbol, exchange, limit_price, quantity, side="SELL", order_tag="TARGET"):
    """
    Places a target (limit) order specifically.
    
    Args:
        tradingsymbol: Trading symbol from Zerodha
        exchange: Exchange (e.g., 'NFO')
        limit_price: Target price
        quantity: FINAL quantity to trade
        side: Usually 'SELL' for target
        order_tag: Tag for the order
    
    Returns:
        order_id: Zerodha order ID
    """
    k = get_kite()
    
    print(f"[BROKER DEBUG] Placing TARGET ORDER:")
    print(f"  - Symbol: {tradingsymbol}")
    print(f"  - Exchange: {exchange}")
    print(f"  - Target Price: {limit_price}")
    print(f"  - Quantity: {quantity}")
    print(f"  - Side: {side}")
    print(f"  - Tag: {order_tag}")
    
    # Convert side to Zerodha format
    tx = k.TRANSACTION_TYPE_BUY if side == 'BUY' else k.TRANSACTION_TYPE_SELL
    
    try:
        order_params = {
            'variety': k.VARIETY_REGULAR,
            'exchange': exchange,
            'tradingsymbol': tradingsymbol,
            'transaction_type': tx,
            'quantity': quantity,
            'product': k.PRODUCT_MIS,
            'order_type': k.ORDER_TYPE_LIMIT,  # Limit order for target
            'price': limit_price,
            'validity': k.VALIDITY_DAY,
            'tag': order_tag
        }
        
        print(f"[BROKER DEBUG] Target order parameters: {order_params}")
        
        order_id = k.place_order(**order_params)
        
        print(f"[BROKER DEBUG] Target order placed successfully: {order_id}")
        return order_id
        
    except Exception as e:
        print(f"[BROKER ERROR] Failed to place target order: {e}")
        print(f"[BROKER ERROR] Target order parameters were: {order_params}")
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
        stoploss: Optional stoploss trigger price
        target: Optional target limit price
    
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
    if stoploss is not None and stoploss > 0:
        try:
            print(f"[BROKER DEBUG] Placing stoploss at trigger price: {stoploss}")
            sl_order_id = place_stoploss_order(
                tradingsymbol, exchange, stoploss, quantity, "SELL", "STOPLOSS"
            )
            result['stoploss_order_id'] = sl_order_id
            print(f"[BROKER DEBUG] Stoploss order placed: {sl_order_id}")
            
        except Exception as e:
            print(f"[BROKER ERROR] Failed to place stoploss order: {e}")
            result['stoploss_error'] = str(e)
    else:
        print(f"[BROKER DEBUG] No stoploss requested (value: {stoploss})")
    
    # Place target order if provided
    if target is not None and target > 0:
        try:
            print(f"[BROKER DEBUG] Placing target at limit price: {target}")
            target_order_id = place_target_order(
                tradingsymbol, exchange, target, quantity, "SELL", "TARGET"
            )
            result['target_order_id'] = target_order_id
            print(f"[BROKER DEBUG] Target order placed: {target_order_id}")
            
        except Exception as e:
            print(f"[BROKER ERROR] Failed to place target order: {e}")
            result['target_error'] = str(e)
    else:
        print(f"[BROKER DEBUG] No target requested (value: {target})")
    
    print(f"[BROKER DEBUG] === BRACKET ORDERS COMPLETE ===")
    return result