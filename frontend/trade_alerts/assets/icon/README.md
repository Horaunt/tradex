# Trade Alerts App Icon

## Instructions to Create Custom App Icon

1. Create a 1024x1024 PNG image named `app_icon.png` in this directory
2. Design should include:
   - Trading/financial theme (trending up arrow, chart, etc.)
   - Blue color scheme (#1976D2) to match the app
   - Clean, modern design that works at small sizes
   - White or light background

## Suggested Design Elements:
- Trending up arrow icon (📈)
- Blue gradient background
- Clean typography if including text
- Rounded corners for modern look

## Alternative Quick Solution:
You can use any 1024x1024 PNG image as a placeholder, or create one using:
- Online icon generators
- Design tools like Canva, Figma
- AI image generators

## After creating the icon:
Run these commands to generate all platform-specific icons:
```
flutter pub get
flutter pub run flutter_launcher_icons:main
```

This will automatically generate icons for:
- Android (various sizes)
- iOS (various sizes) 
- Web (favicon, PWA icons)
- Windows (.ico file)
- macOS (various sizes)
