# Environment Variables Setup Guide

## 🔐 Overview
This guide explains how to configure environment variables for secure management of API keys and configuration in your Trade Alerts Flutter app.

## 📋 Files Created
- `.env` - Your actual secrets (gitignored)
- `.env.example` - Template for reference
- Updated `pubspec.yaml` with flutter_dotenv dependency
- Updated `.gitignore` to exclude `.env` file

## 🛠️ Configuration Steps

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Configure Your Secrets
Edit the `.env` file with your actual values:

```bash
# Zerodha Kite API Configuration
ZERODHA_API_KEY=your_actual_zerodha_api_key
ZERODHA_REDIRECT_URL=https://yourdomain.com/callback

# Backend API Configuration
BACKEND_BASE_URL=http://10.42.204.215:8000

# App Configuration
APP_NAME=Trade Alerts
APP_VERSION=1.0.0
```

### 3. Zerodha API Setup
1. Visit [Kite Connect Developer Console](https://developers.zerodha.com/)
2. Create/select your app
3. Copy your `api_key`
4. Set up your redirect URL
5. Update `.env` with these values

## 🔧 How It Works

### Environment Loading
The app loads environment variables on startup in `main.dart`:
```dart
await dotenv.load(fileName: ".env");
```

### Usage Throughout App
- **API Key**: `dotenv.env['ZERODHA_API_KEY']`
- **Redirect URL**: `dotenv.env['ZERODHA_REDIRECT_URL']`
- **Backend URL**: `dotenv.env['BACKEND_BASE_URL']`

### Error Handling
The app validates that required environment variables are present and shows helpful error messages if missing.

## 🚀 Testing

### 1. Verify Setup
Run the app and check:
- ✅ App starts without errors
- ✅ Environment variables load correctly
- ✅ Zerodha login button works
- ✅ Error handling for missing variables

### 2. Test Authentication Flow
1. Tap account icon in app bar
2. Should open Zerodha login WebView
3. Complete login process
4. Verify token capture and backend communication

## 🔒 Security Benefits

### ✅ What's Secured
- **API Keys** - No longer hardcoded in source
- **URLs** - Configurable per environment
- **Secrets** - Excluded from version control
- **Flexibility** - Easy to change without code updates

### ✅ Best Practices Implemented
- `.env` file gitignored
- `.env.example` for team reference
- Runtime validation of required variables
- Fallback values for non-critical settings

## 🐛 Troubleshooting

### Common Issues
1. **"Environment variables missing"** - Check `.env` file exists and has correct values
2. **WebView not loading** - Verify `ZERODHA_API_KEY` is correct
3. **Backend errors** - Check `BACKEND_BASE_URL` is accessible
4. **Build errors** - Run `flutter pub get` after adding dependency

### Debug Steps
1. Check `.env` file is in project root
2. Verify values don't have quotes or extra spaces
3. Ensure `.env` is listed in `pubspec.yaml` assets
4. Check Flutter console for dotenv loading errors

## 📱 Production Deployment

### Environment-Specific Configuration
Create different `.env` files for different environments:
- `.env.development`
- `.env.staging`
- `.env.production`

Load the appropriate file based on your build configuration.

### CI/CD Integration
- Store secrets in your CI/CD platform's secret management
- Generate `.env` file during build process
- Never commit actual `.env` file to repository

The environment variable setup is now complete and your app is ready for secure production deployment!
