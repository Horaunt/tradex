import os, uuid, json
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from instruments import load_instruments, resolve
from broker import place_limit_option, place_stoploss_order, place_target_order
from notify import push_fcm
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()
INSTR = None
TRADES = {}

class Confirm(BaseModel):
    trade_id: str
    lots: int
    side: str | None = "BUY"
    stoploss: float | None = None
    target: float | None = None

class Raw(BaseModel):
    text: str

@app.on_event("startup")
def boot():
    global INSTR
    INSTR = load_instruments(os.environ.get("INSTRUMENTS_PATH", "instruments.csv"))
    print("[DEBUG] Instruments loaded successfully")

@app.post("/ingest")
def ingest(body: Raw):
    from parser import parse_trade
    print(f"[DEBUG] Incoming request body: {body.dict()}")

    try:
        data = parse_trade(body.text)
    except Exception as e:
        print(f"[ERROR] Exception in parse_trade: {e}")
        raise HTTPException(400, "parse_trade_exception")

    print(f"[DEBUG] Parsed data from parser: {data}")

    if not data:
        print(f"[ERROR] parse_trade failed for text: {body.text}")
        raise HTTPException(400, "unparsable")

    try:
        res = resolve(
            INSTR,
            data["underlying"],
            int(data["day"]),
            data["month"],
            int(data["year"]),
            float(data["strike"]),
            data["opt"],
        )
    except Exception as e:
        print(f"[ERROR] Exception in resolve: {e}")
        raise HTTPException(500, "resolve_exception")

    print(
        f"[DEBUG] Resolve called with: underlying={data['underlying']} "
        f"day={data['day']} month={data['month']} year={data['year']} "
        f"strike={data['strike']} opt={data['opt']}"
    )
    print(f"[DEBUG] Resolve result: {res}")

    if not res:
        print(f"[ERROR] Instrument not found for: {data}")
        raise HTTPException(404, "instrument_not_found")

    # Get lot size from resolved instrument data
    lot_size = res.get("lot_size")
    tradingsymbol = res.get("tradingsymbol")
    
    # Additional debugging for lot size
    print(f"[DEBUG] Raw lot_size from resolve: {lot_size} (type: {type(lot_size)})")
    print(f"[DEBUG] Trading symbol: {tradingsymbol}")
    
    # Ensure lot_size is a valid integer
    try:
        lot_size = int(lot_size) if lot_size is not None else None
    except (ValueError, TypeError) as e:
        print(f"[ERROR] Invalid lot_size format: {lot_size}, error: {e}")
        lot_size = None
    
    if not lot_size or lot_size <= 0:
        print(f"[ERROR] Invalid or missing lot size for instrument: {tradingsymbol}")
        print(f"[ERROR] Full instrument data: {res}")
        raise HTTPException(500, "invalid_lot_size")
    
    print(f"[DEBUG] Final validated lot_size: {lot_size}")

    tid = str(uuid.uuid4())
    payload = {
        **data,
        **res,
        "lot_size": lot_size,  # Store the validated lot size
        "trade_id": tid,
        "title": f"{data['underlying']} {data['day']} {data['month']} {int(data['strike'])} {data['opt']}",
        "entry": f"{data['entry_low']}-{data['entry_high']}",
    }

    TRADES[tid] = payload
    print(f"[DEBUG] Final trade payload stored: {payload}")
    print(f"[DEBUG] Stored lot_size for trade {tid}: {TRADES[tid]['lot_size']}")

    fcm_payload = {k: json.dumps(v) if isinstance(v, (list, dict)) else str(v) for k, v in payload.items()}
    print("[FCM_PAYLOAD_JSON]", json.dumps(fcm_payload, indent=2))

    try:
        push_fcm("trades", fcm_payload)
        print(f"[DEBUG] Sent FCM notification for trade_id={tid}")
    except Exception as e:
        print(f"[ERROR] Failed to push FCM notification: {e}")

    return {"trade_id": tid}

@app.post("/order")
def order(c: Confirm):
    print(f"[DEBUG] Place order request received: {c.dict()}")

    # Validate trade exists
    t = TRADES.get(c.trade_id)
    if not t:
        print(f"[ERROR] Trade not found for trade_id={c.trade_id}")
        print(f"[DEBUG] Available trade_ids: {list(TRADES.keys())}")
        raise HTTPException(404, "trade_not_found")

    # Get and validate lot size
    lot_size = t.get("lot_size")
    tradingsymbol = t.get("tradingsymbol")
    exchange = t.get("exchange")
    
    print(f"[DEBUG] Retrieved lot_size: {lot_size} (type: {type(lot_size)})")
    print(f"[DEBUG] Trading symbol: {tradingsymbol}")
    print(f"[DEBUG] Exchange: {exchange}")
    
    if not lot_size:
        print(f"[ERROR] Lot size not available for instrument: {tradingsymbol}")
        print(f"[ERROR] Full trade data: {t}")
        raise HTTPException(500, "lot_size_not_found")

    # Ensure lot_size is integer for calculation
    try:
        lot_size = int(lot_size)
    except (ValueError, TypeError) as e:
        print(f"[ERROR] Invalid lot_size format in stored trade: {lot_size}, error: {e}")
        raise HTTPException(500, "invalid_lot_size_format")

    # Calculate final quantity - this is correct now
    quantity = c.lots * lot_size
    print(f"[DEBUG] Order calculation: {c.lots} lots × {lot_size} lot_size = {quantity} quantity")

    # Validate entry price
    try:
        px = float(t["entry_high"])
        print(f"[DEBUG] Order price: {px}")
    except Exception as e:
        print(f"[ERROR] Invalid entry_high value in trade={t}: {e}")
        raise HTTPException(500, "invalid_entry_price")
    
    print(f"[DEBUG] Final main order parameters:")
    print(f"  - tradingsymbol: {tradingsymbol}")
    print(f"  - exchange: {exchange}")
    print(f"  - price: {px}")
    print(f"  - quantity: {quantity} (final calculated quantity)")
    print(f"  - side: {c.side.upper()}")
    
    # Check for stoploss and target (ignore if 0 or None)
    has_stoploss = c.stoploss is not None and c.stoploss > 0
    has_target = c.target is not None and c.target > 0
    print(f"[DEBUG] Exit orders requested - Stoploss: {has_stoploss} (value: {c.stoploss}), Target: {has_target} (value: {c.target})")
    
    if has_stoploss:
        print(f"[DEBUG] Stoploss trigger price: {c.stoploss}")
    if has_target:
        print(f"[DEBUG] Target limit price: {c.target}")

    # Place the main order
    main_order_id = None
    stoploss_order_id = None
    target_order_id = None
    
    try:
        print("[DEBUG] === PLACING MAIN ORDER ===")
        main_order_id = place_limit_option(
            tradingsymbol,
            exchange,
            px,
            quantity,
            c.side.upper(),
        )
        print(f"[DEBUG] Main order placed successfully: order_id={main_order_id}")
        
    except Exception as e:
        print(f"[ERROR] Failed to place main order: {e}")
        print(f"[ERROR] Order parameters were: symbol={tradingsymbol}, quantity={quantity}, price={px}")
        raise HTTPException(500, f"main_order_placement_failed: {str(e)}")

    # Place stoploss order if requested
    if has_stoploss:
        try:
            print("[DEBUG] === PLACING STOPLOSS ORDER ===")
            print(f"[DEBUG] Stoploss order parameters:")
            print(f"  - tradingsymbol: {tradingsymbol}")
            print(f"  - exchange: {exchange}")
            print(f"  - trigger_price: {c.stoploss}")
            print(f"  - quantity: {quantity}")
            print(f"  - side: SELL (exit order)")
            
            stoploss_order_id = place_stoploss_order(
                tradingsymbol,
                exchange,
                c.stoploss,  # trigger price
                quantity,
                "SELL",  # Always SELL for exit
                "STOPLOSS"
            )
            print(f"[DEBUG] Stoploss order placed successfully: order_id={stoploss_order_id}")
            
        except Exception as e:
            print(f"[ERROR] Failed to place stoploss order: {e}")
            print(f"[ERROR] Stoploss parameters were: symbol={tradingsymbol}, quantity={quantity}, trigger_price={c.stoploss}")
            print(f"[WARNING] Main order was placed successfully: {main_order_id}")
            # Don't fail the entire request if stoploss fails
            stoploss_order_id = f"FAILED: {str(e)}"

    # Place target order if requested
    if has_target:
        try:
            print("[DEBUG] === PLACING TARGET ORDER ===")
            print(f"[DEBUG] Target order parameters:")
            print(f"  - tradingsymbol: {tradingsymbol}")
            print(f"  - exchange: {exchange}")
            print(f"  - limit_price: {c.target}")
            print(f"  - quantity: {quantity}")
            print(f"  - side: SELL (exit order)")
            
            target_order_id = place_target_order(
                tradingsymbol,
                exchange,
                c.target,  # limit price
                quantity,
                "SELL",  # Always SELL for exit
                "TARGET"
            )
            print(f"[DEBUG] Target order placed successfully: order_id={target_order_id}")
            
        except Exception as e:
            print(f"[ERROR] Failed to place target order: {e}")
            print(f"[ERROR] Target parameters were: symbol={tradingsymbol}, quantity={quantity}, limit_price={c.target}")
            print(f"[WARNING] Main order was placed successfully: {main_order_id}")
            # Don't fail the entire request if target fails
            target_order_id = f"FAILED: {str(e)}"

    # Prepare response
    response = {
        "main_order_id": main_order_id,
        "status": "success",
        "quantity": quantity,
        "lots": c.lots,
        "lot_size": lot_size
    }
    
    if has_stoploss:
        response["stoploss_order_id"] = stoploss_order_id
        response["stoploss_price"] = c.stoploss
        
    if has_target:
        response["target_order_id"] = target_order_id
        response["target_price"] = c.target
    
    print(f"[DEBUG] === ORDER PLACEMENT COMPLETE ===")
    print(f"[DEBUG] Final response: {response}")
    
    return response