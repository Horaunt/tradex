import os, uuid, json
from fastapi import FastAPI, HTTPException,Header,Request
from pydantic import BaseModel
from kiteconnect import KiteConnect
from instruments import load_instruments, resolve
from broker import place_limit_option, place_stoploss_order, place_target_order
from notify import push_fcm
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()
INSTR = None
TRADES = {}
# kite = KiteConnect(api_key=Z_API_KEY)
Z_API_KEY = os.getenv("Z_API_KEY")
Z_API_SECRET = os.getenv("Z_API_SECRET")
kite = KiteConnect(api_key=Z_API_KEY)

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
def order(c: Confirm, access_token: str = Header(...)):
    print(f"[DEBUG] Place order request received: {c.dict()}")
    print(f"[DEBUG] Access token received from client.")

    # Initialize Kite client with the provided access token
    kite = KiteConnect(api_key=Z_API_KEY)
    kite.set_access_token(access_token)

    # Validate trade exists
    t = TRADES.get(c.trade_id)
    if not t:
        raise HTTPException(404, "trade_not_found")

    lot_size = int(t.get("lot_size"))
    tradingsymbol = t.get("tradingsymbol")
    exchange = t.get("exchange")

    quantity = c.lots * lot_size
    try:
        px = float(t["entry_high"])
    except Exception:
        raise HTTPException(500, "invalid_entry_price")

    has_stoploss = c.stoploss is not None and c.stoploss > 0
    has_target = c.target is not None and c.target > 0

    main_order_id = None
    stoploss_order_id = None
    target_order_id = None

    try:
        main_order_id = kite.place_order(
            variety="regular",
            exchange=exchange,
            tradingsymbol=tradingsymbol,
            transaction_type=c.side.upper(),
            quantity=quantity,
            product="MIS",
            order_type="LIMIT",
            price=px,
            validity="DAY"
        )
    except Exception as e:
        raise HTTPException(500, f"main_order_placement_failed: {str(e)}")

    if has_stoploss:
        try:
            stoploss_order_id = kite.place_order(
                variety="regular",
                exchange=exchange,
                tradingsymbol=tradingsymbol,
                transaction_type="SELL",
                quantity=quantity,
                product="MIS",
                order_type="SL",
                trigger_price=c.stoploss,
                validity="DAY"
            )
        except Exception as e:
            stoploss_order_id = f"FAILED: {str(e)}"

    if has_target:
        try:
            target_order_id = kite.place_order(
                variety="regular",
                exchange=exchange,
                tradingsymbol=tradingsymbol,
                transaction_type="SELL",
                quantity=quantity,
                product="MIS",
                order_type="LIMIT",
                price=c.target,
                validity="DAY"
            )
        except Exception as e:
            target_order_id = f"FAILED: {str(e)}"

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

    return response

class AuthRequest(BaseModel):
    request_token: str

@app.post("/api/zerodha/auth")
async def zerodha_auth(auth_request: AuthRequest):
    try:
        # Exchange request_token for access_token
        data = kite.generate_session(
            auth_request.request_token,
            api_secret=Z_API_SECRET
        )

        access_token = data["access_token"]
        kite.set_access_token(access_token)

        # (Optional) Save the access_token securely for later use
        with open("access_token.txt", "w") as f:
            f.write(access_token)

        return {
            "status": "success",
            "message": "Authentication successful",
            "access_token": access_token
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))