# Zerodha Kite Authentication Setup Guide

## 🔐 Overview
This guide explains how to set up and use the Zerodha Kite authentication feature in your Trade Alerts Flutter app.

## 📋 Prerequisites
1. Zerodha Kite Connect API account
2. Your API Key from Zerodha Developer Console
3. A registered redirect URL

## 🛠️ Setup Steps

### 1. Get Zerodha API Credentials
1. Visit [Kite Connect Developer Console](https://developers.zerodha.com/)
2. Create a new app or use existing one
3. Note down your `api_key` and `api_secret`
4. Set up your redirect URL (e.g., `https://yourdomain.com/callback`)

### 2. Update Configuration
Replace the placeholder values in the code:

**In `lib/main.dart`:**
```dart
// Line 612-614
builder: (context) => const ZerodhaLoginScreen(
  apiKey: 'YOUR_ACTUAL_API_KEY', // Replace with your Zerodha API key
  redirectUrl: 'https://yourdomain.com/callback', // Replace with your redirect URL
),
```

**In `lib/screens/login_error_screen.dart`:**
```dart
// Line 110-112
builder: (context) => const ZerodhaLoginScreen(
  apiKey: 'YOUR_ACTUAL_API_KEY', // Replace with your API key
  redirectUrl: 'https://yourdomain.com/callback',
),
```

### 3. Backend API Endpoint
Ensure your backend has the `/api/zerodha/auth` endpoint that:
- Accepts POST requests with `{ "request_token": "<token>" }`
- Exchanges the request token for access token using your `api_secret`
- Returns success/failure response

## 🚀 How It Works

### Authentication Flow:
1. **User clicks "Connect Zerodha Account"** → Opens WebView with Kite login
2. **User logs in** → Zerodha redirects to your callback URL with `request_token`
3. **App captures token** → Extracts token from redirect URL
4. **Send to backend** → POST request to `/api/zerodha/auth` with token
5. **Backend processes** → Exchanges token for access token using `api_secret`
6. **Show result** → Success or error screen based on backend response

### File Structure:
```
lib/
├── services/
│   └── auth_service.dart          # Backend API communication
├── screens/
│   ├── zerodha_login_screen.dart  # WebView login interface
│   ├── login_success_screen.dart  # Success confirmation
│   └── login_error_screen.dart    # Error handling
└── main.dart                      # Integration with main app
```

## 🎯 Features

### ✅ Implemented Features:
- **WebView Integration** - Seamless Kite login experience
- **Token Capture** - Automatic extraction from redirect URL
- **Backend Communication** - Secure token exchange via your API
- **Error Handling** - Comprehensive error states and retry options
- **Modern UI** - Consistent with app design language
- **Navigation** - Proper screen transitions and back navigation

### 🔧 Customization Options:
- **API Endpoints** - Easily configurable backend URLs
- **UI Theming** - Matches your app's color scheme
- **Error Messages** - Customizable error handling
- **Success Actions** - Configurable post-authentication flow

## 🧪 Testing

### Test the Flow:
1. Run `flutter pub get` to install WebView dependency
2. Update API key and redirect URL in the code
3. Ensure your backend `/api/zerodha/auth` endpoint is running
4. Launch the app and tap the account icon in the app bar
5. Complete the Zerodha login process

### Expected Behavior:
- ✅ WebView opens with Kite login page
- ✅ After login, app captures the token automatically
- ✅ Loading indicator shows during backend communication
- ✅ Success screen appears on successful authentication
- ✅ Error screen with retry option on failure

## 🔒 Security Notes
- Request tokens are only valid for a short time
- Access tokens should be stored securely on your backend
- Never expose your `api_secret` in the Flutter app
- Use HTTPS for your redirect URL in production

## 🐛 Troubleshooting

### Common Issues:
1. **WebView not loading** - Check internet connection and API key
2. **Token not captured** - Verify redirect URL matches exactly
3. **Backend errors** - Check API endpoint and request format
4. **Navigation issues** - Ensure proper screen transitions

### Debug Tips:
- Check Flutter console for WebView navigation logs
- Verify backend receives the correct request format
- Test redirect URL in browser first
- Use network inspector to debug API calls

## 📱 Usage in App
- **App Bar Icon** - Tap account icon to start authentication
- **Empty State Button** - "Connect Zerodha Account" when no trades
- **Retry Mechanism** - Error screen provides retry option
- **Navigation** - Proper back navigation to main app

The Zerodha authentication is now fully integrated and ready for production use!
