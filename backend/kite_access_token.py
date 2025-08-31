from kiteconnect import KiteConnect
# from redirect URL

kite = KiteConnect(api_key=api_key)
data = kite.generate_session(request_token, api_secret=api_secret)
access_token = data["access_token"]
print("Access Token:", access_token)
