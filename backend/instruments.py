import pandas as pd
from datetime import datetime

MONTHS = {
    'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
    'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
}

def load_instruments(path='instruments.csv'):
    df = pd.read_csv(path)
    df['expiry'] = pd.to_datetime(df['expiry'], errors='coerce')
    return df

def resolve(df, underlying, day, month, year, strike, opt):
    print(f"[DEBUG] Resolving: {underlying} {day}-{month}-{year} {strike} {opt}")

    df = df[
        (df['exchange'] == 'NFO') &
        (df['name'].str.upper() == underlying.upper().strip()) &
        (df['instrument_type'].str.upper().str.endswith(opt.upper().strip()))
    ]

    if df.empty:
        print("[DEBUG] No instruments matched underlying+opt filter.")
        return None

    # filter by expiry
    df = df[
        (df['expiry'].dt.year == year) &
        (df['expiry'].dt.month == MONTHS[month.upper()]) &
        (df['expiry'].dt.day == day)
    ]
    if df.empty:
        print("[DEBUG] No instruments matched expiry, falling back to nearest expiry in month.")
        df = df[
            (df['expiry'].dt.year == year) &
            (df['expiry'].dt.month == MONTHS[month.upper()])
        ]

    # Find the strike closest to requested
    df['strike_diff'] = abs(df['strike'] - float(strike))
    df = df.sort_values('strike_diff')

    if df.empty:
        print("[DEBUG] No matching instrument after strike fallback.")
        return None

    target = df.iloc[0]
    print(f"[DEBUG] Resolved instrument: {target.tradingsymbol}, lot_size: {target.lot_size}")
    return {
        'instrument_token': int(target.instrument_token),
        'tradingsymbol': target.tradingsymbol,
        'exchange': target.exchange,
        'lot_size': int(target.lot_size)
    }
