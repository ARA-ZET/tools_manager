# Quick Start: Adding Your Company Logo

## Step 1: Add Your Logo File

1. Save your company logo as `company_logo.png` in the `assets/images/` folder
2. Recommended size: 512x512 pixels
3. Format: PNG with transparent background

## Step 2: Test the Logo

1. Run `flutter pub get` (already done)
2. Hot reload the app to see your logo on:
   - Login screen
   - Register screen
   - Home screen app bar

## Current Status

✅ Logo widget created (`lib/core/widgets/app_logo.dart`)
✅ Login screen updated with logo
✅ Register screen updated with logo
✅ Home screen header updated with logo
✅ Assets folder configured in `pubspec.yaml`
✅ Fallback styling matches your Mallon theme (green/white/black)

## What You'll See

- **With your logo**: Your company logo displays in all locations
- **Without your logo**: Stylized "VERSFELD Tool Manager" text with tool icon

## Platform Icons (Optional)

To update app icons for different platforms:

### Android

Replace files in: `android/app/src/main/res/mipmap-*/`

- `ic_launcher.png` (various sizes: 48px, 72px, 96px, 144px, 192px)

### iOS

Replace files in: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

- Various sizes from 20x20 to 1024x1024

### Web

Replace files in: `web/icons/`

- `Icon-192.png` (192x192)
- `Icon-512.png` (512x512)
- `Icon-maskable-192.png` (192x192)
- `Icon-maskable-512.png` (512x512)
- `favicon.png` (32x32)

## Need Help?

- Check `LOGO_SETUP.md` for detailed instructions
- Logo widget handles automatic fallbacks
- All styling matches your existing green theme
