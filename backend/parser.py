import re
from datetime import datetime
MONTHS={'JAN':1,'FEB':2,'MAR':3,'APR':4,'MAY':5,'JUN':6,'JUL':7,'AUG':8,'SEP':9,'OCT':10,'NOV':11,'DEC':12}
def parse_trade(text):
    sym=re.search(r'Enter:\s*([A-Z]+)\s+(\d{2})\s+([A-Z]{3})\s+(\d{4,6})\s+(CALL|PUT)',text,re.I)
    rng=re.search(r'Entry Price Range:\s*([0-9]+(?:\.[0-9]+)?)\s*-\s*([0-9]+(?:\.[0-9]+)?)',text,re.I)
    sl=re.search(r'Stop\s*Loss:\s*([0-9]+(?:\.[0-9]+)?)',text,re.I)
    tgs=re.findall(r'Target\s*\d+:\s*([0-9]+(?:\.[0-9]+)?)',text,re.I)
    if not (sym and rng and sl):
        return None
    underlying=sym.group(1).upper()
    day=int(sym.group(2))
    mon=sym.group(3).upper()
    strike=float(sym.group(4))
    opt='PE' if sym.group(5).upper().startswith('P') else 'CE'
    year=datetime.utcnow().year if datetime.utcnow().month<=MONTHS[mon] else datetime.utcnow().year+1
    entry_low=float(rng.group(1)); entry_high=float(rng.group(2))
    stoploss=float(sl.group(1))
    targets=[float(x) for x in tgs] if tgs else []
    return {'underlying':underlying,'day':day,'month':mon,'year':year,'strike':strike,'opt':opt,'entry_low':entry_low,'entry_high':entry_high,'stoploss':stoploss,'targets':targets}
