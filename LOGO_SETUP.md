# Company Logo Setup Guide

## Overview

The app has been updated to support your company logo in multiple locations:

- Login screen
- Registration screen
- Home screen header
- Splash screen (for future use)

## Logo File Requirements

### Primary Logo

Place your company logo as: `assets/images/company_logo.png`

**Recommended specifications:**

- Format: PNG with transparent background
- Size: 512x512px minimum for best quality
- Aspect ratio: Square or rectangular (will be scaled proportionally)

### Additional Logo Variants (Optional)

You can also provide different variants for different contexts:

1. **Header Logo**: `assets/images/header_logo.png`

   - Optimized for app bar display
   - Recommended: 240x80px (3:1 aspect ratio)

2. **Splash Logo**: `assets/images/splash_logo.png`

   - Large version for splash screen
   - Recommended: 512x512px

3. **Icon Logo**: `assets/icons/app_icon.png`
   - Square icon version
   - Recommended: 1024x1024px

## Current Implementation

### Logo Widget Locations

1. **Login Screen**: Medium-sized logo above "Welcome Back!" text
2. **Register Screen**: Medium-sized logo above "Join Us!" text
3. **Home Screen**: Small header logo in the app bar
4. **Splash Screen**: Large logo with loading indicator (created but not yet integrated)

### Fallback Behavior

If no logo file is found, the app displays a stylized text-based logo with:

- "VERSFELD" in bold letters
- "Tool Manager" subtitle
- Tool icon
- Brand colors (green theme)

## File Structure

```
assets/
├── images/
│   ├── company_logo.png          # Main logo (required)
│   ├── header_logo.png           # Header variant (optional)
│   └── splash_logo.png           # Splash variant (optional)
├── icons/
│   └── app_icon.png              # App icon (optional)
└── logo/                         # Legacy folder (can be removed)
```

## Integration Steps

1. **Add your logo file(s)**:

   - Copy your company logo to `assets/images/company_logo.png`
   - Ensure the file name matches exactly (case-sensitive)

2. **Test the integration**:

   - Run `flutter pub get` to refresh assets
   - Hot reload or restart the app
   - Check login screen, register screen, and home screen

3. **Customize if needed**:
   - Edit `lib/core/widgets/app_logo.dart` to adjust sizing or styling
   - Update file paths if you prefer different naming

## Platform-Specific Icons

### Android

Update app icons in: `android/app/src/main/res/mipmap-*/ic_launcher.png`

### iOS

Update app icons in: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

### Web

Update web icons in: `web/icons/`

### macOS

Update app icons in: `macos/Runner/Assets.xcassets/AppIcon.appiconset/`

## Notes

- PNG format with transparent background works best
- SVG format can be used but requires additional setup
- High-resolution images will be automatically scaled down
- The app maintains the Mallon theme colors (white/black/green) around the logo
