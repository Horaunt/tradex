import os, uuid, json
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from instruments import load_instruments, resolve
from broker import place_limit_option
from notify import push_fcm
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()
INSTR = None
TRADES = {}

class Confirm(BaseModel):
    trade_id: str
    lots: int
    side: str | None = "BUY"  # default to BUY if not provided

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

    tid = str(uuid.uuid4())
    payload = {
        **data,
        **res,
        "trade_id": tid,
        "title": f"{data['underlying']} {data['day']} {data['month']} {int(data['strike'])} {data['opt']}",
        "entry": f"{data['entry_low']}-{data['entry_high']}",
    }
    TRADES[tid] = payload
    print(f"[DEBUG] Final trade payload to push: {payload}")

    fcm_payload = {}
    for k, v in payload.items():
        if isinstance(v, (list, dict)):
            fcm_payload[k] = json.dumps(v)
        else:
            fcm_payload[k] = str(v)

    # 🔹 Print the exact JSON that gets sent to the app
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

    t = TRADES.get(c.trade_id)
    if not t:
        print(f"[ERROR] Trade not found for trade_id={c.trade_id}")
        raise HTTPException(404, "trade_not_found")

    try:
        px = float(t["entry_high"])
    except Exception as e:
        print(f"[ERROR] Invalid entry_high value in trade={t}: {e}")
        raise HTTPException(500, "invalid_entry_price")

    try:
        oid = place_limit_option(
            t["tradingsymbol"],
            t["exchange"],
            px,
            int(c.lots),
            c.side.upper(),
        )
        print(f"[DEBUG] Order placed successfully: order_id={oid}")
    except Exception as e:
        print(f"[ERROR] Failed to place order: {e}")
        raise HTTPException(500, "order_placement_failed")

    return {"order_id": oid, "status": "success"}
