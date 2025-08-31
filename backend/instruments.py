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

    # Step 1: Filter down to underlying + option type + strike
    df = df[
        (df['exchange'] == 'NFO') &
        (df['name'].str.upper() == underlying.upper().strip()) &
        (df['instrument_type'].str.upper().isin(['CE', 'PE', 'OPTIDX', 'OPTSTK'])) &
        (df['strike'] == float(strike))
    ]
    
    if df.empty:
        print("[DEBUG] No instruments matched initial filters.")
        return None

    # Step 2: Try exact expiry match
    exact_match = df[
        (df['expiry'].dt.year == year) &
        (df['expiry'].dt.month == MONTHS[month.upper()]) &
        (df['expiry'].dt.day == day) &
        (df['tradingsymbol'].str.upper().str.endswith(opt.upper().strip()))
    ]
    if not exact_match.empty:
        target = exact_match.iloc[0]
        print(f"[DEBUG] Exact match found: {target.tradingsymbol}")
        return {
            'instrument_token': int(target.instrument_token),
            'tradingsymbol': target.tradingsymbol,
            'exchange': target.exchange
        }

    # Step 3: If no exact match, fallback to nearest expiry in that month
    fallback = df[
        (df['expiry'].dt.year == year) &
        (df['expiry'].dt.month == MONTHS[month.upper()]) &
        (df['tradingsymbol'].str.upper().str.endswith(opt.upper().strip()))
    ]
    if not fallback.empty:
        target = fallback.sort_values('expiry').iloc[0]  # nearest expiry in that month
        print(f"[DEBUG] Monthly expiry fallback match: {target.tradingsymbol}")
        return {
            'instrument_token': int(target.instrument_token),
            'tradingsymbol': target.tradingsymbol,
            'exchange': target.exchange
        }

    # Step 4: Final fallback — pick the nearest future expiry
    future = df[df['expiry'] >= pd.Timestamp(year, MONTHS[month.upper()], day)]
    if not future.empty:
        target = future.sort_values('expiry').iloc[0]
        print(f"[DEBUG] Nearest future expiry fallback: {target.tradingsymbol}")
        return {
            'instrument_token': int(target.instrument_token),
            'tradingsymbol': target.tradingsymbol,
            'exchange': target.exchange
        }

    print("[DEBUG] No matching instrument found even after fallbacks.")
    return None