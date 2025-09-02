# Quick App Icon Setup

## Immediate Solution:
1. Copy an existing icon as a temporary placeholder:
   ```cmd
   copy web\icons\Icon-512.png assets\icon\app_icon.png
   ```

2. Then run the icon generation:
   ```cmd
   flutter pub run flutter_launcher_icons:main
   ```

3. Generate splash screen:
   ```cmd
   flutter pub run flutter_native_splash:create
   ```

## Alternative: Create Custom Icon
1. Open `assets/icon/generate_icon.html` in your browser
2. Download the generated icon as `app_icon.png`
3. Place it in `assets/icon/` folder
4. Run the commands above

## If you get permission errors:
- Run PowerShell as Administrator
- Or manually copy the file using File Explorer

The temporary solution will work perfectly for testing, and you can replace it with a custom icon later.
