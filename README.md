# Trading Assistant

A real-time trading assistant that monitors Telegram trade alerts, extracts structured trade information, sends notifications, and enables users to place trades through Zerodha Kite Connect directly from the application.

## Features

* 📡 Real-time Telegram trade-alert monitoring
* 🔍 Automatic parsing of trade alerts
* 📊 Extraction of:

  * Trading symbol
  * Exchange
  * Buy/Sell direction
  * Entry price
  * Stop-loss
  * Target price
  * Quantity/lots
* 🔔 Firebase Cloud Messaging (FCM) push notifications
* 📈 Live market-price integration
* 🏦 Zerodha Kite Connect integration
* ⚡ Automated order placement
* 📦 Lot-size and instrument resolution
* 🔐 Secure API-based backend
* 🧩 Scalable architecture for multiple users and strategies

## Architecture

```text
Telegram Channel
       │
       ▼
Telegram Listener
       │
       ▼
Trade Alert Parser
       │
       ├──────────────► Market Data API
       │
       ▼
Trade Validation
       │
       ▼
FastAPI Backend
       │
       ├──────────────► Firebase FCM
       │                      │
       │                      ▼
       │                 Flutter App
       │                      │
       │                      ▼
       │                User Confirmation
       │
       ▼
Zerodha Kite Connect
       │
       ▼
Order Execution
```

## Tech Stack

### Mobile Application

* Flutter
* Dart
* Firebase Cloud Messaging

### Backend

* Python
* FastAPI
* REST APIs

### Trading

* Zerodha Kite Connect
* Instrument master data
* Automated order placement

### Market Data

* Alpha Vantage
* Instrument metadata

### Infrastructure

* AWS API Gateway
* Cloud-based backend services

## Trade Processing Flow

1. The system monitors a configured Telegram channel.
2. A new trade alert is received.
3. The alert parser extracts the relevant trading information.
4. The instrument is resolved using the instrument master data.
5. The trade is validated.
6. A push notification is sent to the user's mobile device.
7. The user selects the required number of lots.
8. The backend calculates the corresponding quantity.
9. The order is submitted through Zerodha Kite Connect.
10. The application receives the order response and displays the status.

## Example Alert

```text
BANKNIFTY 48500 CE
BUY ABOVE 120
SL 90
TARGET 180
```

The parser converts the message into structured data:

```json
{
  "symbol": "BANKNIFTY",
  "instrument": "48500 CE",
  "side": "BUY",
  "entry": 120,
  "stop_loss": 90,
  "target": 180
}
```

## Project Structure

```text
trading-assistant/
├── backend/
│   ├── main.py
│   ├── instruments.py
│   ├── routes/
│   ├── services/
│   └── requirements.txt
├── mobile/
│   ├── lib/
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
├── data/
│   └── instruments.csv
└── README.md
```

## Environment Variables

Create a `.env` file in the backend:

```env
KITE_API_KEY=
KITE_API_SECRET=
KITE_ACCESS_TOKEN=
TELEGRAM_API_ID=
TELEGRAM_API_HASH=
TELEGRAM_SESSION=
ALPHA_VANTAGE_API_KEY=
FIREBASE_CREDENTIALS=
```

## Backend Setup

```bash
cd backend
python -m venv venv
```

### Linux/macOS

```bash
source venv/bin/activate
```

### Windows

```bash
venv\Scripts\activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

Start the FastAPI server:

```bash
uvicorn main:app --reload
```

## Flutter Setup

```bash
cd mobile
flutter pub get
flutter run
```

## Instrument Resolution

The backend maintains instrument information using `instruments.csv`. This allows trade alerts to be mapped to the correct exchange instrument and trading symbol before an order is submitted.

The system also accounts for derivative lot sizes so that the selected number of lots is converted into the correct order quantity.

## Safety

The application is designed as a trading automation tool and should not be treated as financial advice.

Before enabling live trading:

* Verify parsed trade information.
* Verify the resolved trading symbol.
* Verify quantity and lot size.
* Verify the order type and transaction side.
* Test thoroughly using appropriate non-production configurations.

## Future Improvements

* Automated trailing stop-loss
* Multi-broker support
* Advanced portfolio and P&L dashboard
* Trade history and analytics
* Strategy performance tracking
* WebSocket-based real-time market data
* Risk-management rules
* Maximum daily-loss protection
* Paper-trading mode
* Multi-channel Telegram monitoring
* AI-assisted trade-alert classification
