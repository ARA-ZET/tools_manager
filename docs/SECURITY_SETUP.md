# Security Setup Guide

## Overview
This guide explains how to securely configure Firebase and protect API keys when working with the Versfeld Tool Manager and pushing to GitHub.

## 🔒 Security Principles

**NEVER commit these files to version control:**
- `lib/firebase_options.dart` - Contains Firebase API keys
- `android/app/google-services.json` - Android Firebase configuration
- `ios/Runner/GoogleService-Info.plist` - iOS Firebase configuration
- `.env` files - Environment variables
- Any file containing API keys, passwords, or tokens

## 📋 Initial Setup (For New Developers)

### 1. Firebase Configuration

**Step 1: Get Firebase Configuration Files**

You need to obtain these files from:
- Firebase Console: https://console.firebase.google.com/
- Or from the project administrator

**Step 2: Copy Template Files**

```bash
# Copy and rename template files
cp lib/firebase_options.dart.template lib/firebase_options.dart
cp android/app/google-services.json.template android/app/google-services.json
cp ios/Runner/GoogleService-Info.plist.template ios/Runner/GoogleService-Info.plist
```

**Step 3: Fill in Your Firebase Values**

Edit each file and replace the placeholder values:

#### `lib/firebase_options.dart`
Replace:
- `YOUR_WEB_API_KEY`
- `YOUR_ANDROID_API_KEY`
- `YOUR_IOS_API_KEY`
- `YOUR_PROJECT_ID`
- `YOUR_APP_ID` values
- etc.

#### `android/app/google-services.json`
Download from Firebase Console:
1. Go to Project Settings → General
2. Select your Android app
3. Click "google-services.json" download button
4. Replace the template file

#### `ios/Runner/GoogleService-Info.plist`
Download from Firebase Console:
1. Go to Project Settings → General
2. Select your iOS app
3. Click "GoogleService-Info.plist" download button
4. Replace the template file

### 2. Verify .gitignore

The `.gitignore` file should already contain these entries:

```gitignore
# Firebase configuration files
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
lib/firebase_options.dart

# Environment files
.env
.env.*
*.env
```

### 3. Test Configuration

```bash
# Check that sensitive files are ignored
git status

# You should NOT see:
# - firebase_options.dart
# - google-services.json
# - GoogleService-Info.plist
```

## 🚀 Firebase Configuration Methods

### Option A: Using FlutterFire CLI (Recommended)

The FlutterFire CLI automatically generates `firebase_options.dart`:

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Login to Firebase
firebase login

# Configure Firebase for your Flutter project
flutterfire configure

# Select your Firebase project
# This will generate firebase_options.dart automatically
```

**Important:** After running `flutterfire configure`, the generated `firebase_options.dart` will still be gitignored.

### Option B: Manual Configuration

If you prefer manual setup, follow the Initial Setup steps above.

## 🔐 Firebase Security Rules

Your Firestore security rules are in `firestore.rules` and can be committed to version control. These rules protect your database, not your API keys.

**Current security model:**
- Role-based access control (Admin, Supervisor, Worker)
- Server-side permission enforcement
- Rules validate operations based on user roles

## 📦 GitHub Repository Setup

### Before First Push

1. **Remove sensitive files from Git history** (if already committed):

```bash
# Check what's currently tracked
git ls-files | grep -E "(firebase_options|google-services|GoogleService-Info)"

# If any sensitive files are tracked, remove them:
git rm --cached lib/firebase_options.dart
git rm --cached android/app/google-services.json
git rm --cached ios/Runner/GoogleService-Info.plist

# Commit the removal
git add .gitignore
git commit -m "chore: Remove sensitive Firebase configuration from version control"
```

2. **Verify nothing sensitive is staged**:

```bash
git status
git diff --cached
```

3. **Create initial commit**:

```bash
git add .
git commit -m "Initial commit: Versfeld Tool Manager"
git branch -M main
```

4. **Push to GitHub**:

```bash
# Add your GitHub repository as remote
git remote add origin https://github.com/YOUR_USERNAME/versfeld.git

# Push to GitHub
git push -u origin main
```

## 🔄 For Team Collaborators

### When Cloning the Repository

1. **Clone the repository**:
```bash
git clone https://github.com/YOUR_USERNAME/versfeld.git
cd versfeld
```

2. **Contact project admin** for Firebase configuration files

3. **Set up Firebase configuration** using one of these methods:
   - Run `flutterfire configure` (easiest)
   - Manually copy the three configuration files to correct locations

4. **Install dependencies**:
```bash
flutter pub get
```

5. **Run the app**:
```bash
flutter run
```

## 🛡️ Additional Security Best Practices

### 1. Environment Variables (Future Enhancement)

For additional security, consider using environment variables:

```dart
// .env file (never commit this)
FIREBASE_WEB_API_KEY=your_key_here
FIREBASE_PROJECT_ID=your_project_id

// Load in app
import 'package:flutter_dotenv/flutter_dotenv.dart';

await dotenv.load();
final apiKey = dotenv.env['FIREBASE_WEB_API_KEY'];
```

### 2. Firebase API Key Restrictions

In Firebase Console, restrict your API keys:

1. Go to Google Cloud Console → APIs & Services → Credentials
2. Select your API key
3. Add application restrictions:
   - **HTTP referrers** for Web
   - **Android apps** for Android (add SHA-1 fingerprint)
   - **iOS apps** for iOS (add bundle ID)

### 3. Firestore Security Rules

Always enforce security at the database level:

```javascript
// Example from firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isAdmin() {
      return isAuthenticated() && 
             getUserRole(request.auth.uid) == 'admin';
    }
    
    // Protect sensitive collections
    match /tools/{toolId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }
  }
}
```

## ⚠️ What If I Accidentally Committed API Keys?

### If Keys Are Already on GitHub:

1. **Rotate ALL API keys immediately**:
   - Generate new keys in Firebase Console
   - Update local configuration files
   - Revoke old keys

2. **Remove from Git history**:
```bash
# Use BFG Repo-Cleaner (recommended)
brew install bfg
bfg --delete-files firebase_options.dart
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Or use git filter-branch (slower)
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch lib/firebase_options.dart" \
  --prune-empty --tag-name-filter cat -- --all
```

3. **Force push** (⚠️ DANGER: coordinate with team):
```bash
git push origin --force --all
git push origin --force --tags
```

## 📚 Resources

- [Firebase Security Best Practices](https://firebase.google.com/docs/projects/api-keys)
- [FlutterFire CLI Documentation](https://firebase.flutter.dev/docs/cli)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [GitHub Security Best Practices](https://docs.github.com/en/code-security/getting-started/best-practices-for-preventing-data-leaks-in-your-organization)

## 📞 Support

If you need Firebase configuration files or have security concerns:
- Contact: richardatclm@gmail.com
- Or create an issue in the GitHub repository (don't include sensitive data!)

## ✅ Security Checklist

Before pushing to GitHub:
- [ ] `.gitignore` includes all sensitive files
- [ ] `firebase_options.dart` is not tracked by Git
- [ ] `google-services.json` is not tracked by Git
- [ ] `GoogleService-Info.plist` is not tracked by Git
- [ ] Template files are committed (`.template` extensions)
- [ ] No API keys in commit messages
- [ ] No passwords or tokens in code
- [ ] Firestore security rules are properly configured
- [ ] README includes setup instructions for new developers

---

**Last Updated:** October 20, 2025
