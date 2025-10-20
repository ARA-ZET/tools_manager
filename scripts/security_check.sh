#!/bin/bash

# Versfeld Tool Manager - Security Setup Script
# This script helps remove sensitive files from Git tracking

set -e

echo "🔒 Versfeld Security Setup"
echo "=========================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not a git repository${NC}"
    exit 1
fi

echo "Step 1: Checking for sensitive files in Git tracking..."
echo ""

# Check if sensitive files are tracked
TRACKED_FILES=""

if git ls-files --error-unmatch lib/firebase_options.dart > /dev/null 2>&1; then
    TRACKED_FILES="${TRACKED_FILES}lib/firebase_options.dart\n"
fi

if git ls-files --error-unmatch android/app/google-services.json > /dev/null 2>&1; then
    TRACKED_FILES="${TRACKED_FILES}android/app/google-services.json\n"
fi

if git ls-files --error-unmatch ios/Runner/GoogleService-Info.plist > /dev/null 2>&1; then
    TRACKED_FILES="${TRACKED_FILES}ios/Runner/GoogleService-Info.plist\n"
fi

if [ -z "$TRACKED_FILES" ]; then
    echo -e "${GREEN}✓ No sensitive files are currently tracked${NC}"
else
    echo -e "${YELLOW}⚠️  Found sensitive files in Git tracking:${NC}"
    echo -e "$TRACKED_FILES"
    echo ""
    read -p "Remove these files from Git tracking? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing sensitive files from Git..."
        git rm --cached lib/firebase_options.dart 2>/dev/null || true
        git rm --cached android/app/google-services.json 2>/dev/null || true
        git rm --cached ios/Runner/GoogleService-Info.plist 2>/dev/null || true
        echo -e "${GREEN}✓ Files removed from Git tracking${NC}"
    fi
fi

echo ""
echo "Step 2: Verifying .gitignore..."
echo ""

if grep -q "lib/firebase_options.dart" .gitignore; then
    echo -e "${GREEN}✓ .gitignore is properly configured${NC}"
else
    echo -e "${YELLOW}⚠️  .gitignore may need updating${NC}"
fi

echo ""
echo "Step 3: Checking for Firebase configuration files..."
echo ""

if [ -f "lib/firebase_options.dart" ]; then
    echo -e "${GREEN}✓ firebase_options.dart exists${NC}"
else
    echo -e "${YELLOW}⚠️  firebase_options.dart not found${NC}"
    echo "   Run: cp lib/firebase_options.dart.template lib/firebase_options.dart"
    echo "   Then fill in your Firebase configuration"
fi

if [ -f "android/app/google-services.json" ]; then
    echo -e "${GREEN}✓ google-services.json exists${NC}"
else
    echo -e "${YELLOW}⚠️  google-services.json not found${NC}"
    echo "   Download from Firebase Console or copy template"
fi

if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo -e "${GREEN}✓ GoogleService-Info.plist exists${NC}"
else
    echo -e "${YELLOW}⚠️  GoogleService-Info.plist not found${NC}"
    echo "   Download from Firebase Console or copy template"
fi

echo ""
echo "Step 4: Git status check..."
echo ""

# Show what would be committed
STAGED=$(git diff --cached --name-only)
if [ -z "$STAGED" ]; then
    echo "No files staged for commit"
else
    echo "Staged files:"
    git diff --cached --name-only | while read file; do
        if [[ $file == *"firebase_options.dart"* ]] || \
           [[ $file == *"google-services.json"* ]] || \
           [[ $file == *"GoogleService-Info.plist"* ]]; then
            echo -e "${RED}  ⚠️  $file ${NC}"
        else
            echo "  ✓ $file"
        fi
    done
fi

echo ""
echo "=========================="
echo "🎉 Security check complete!"
echo ""
echo "Next steps:"
echo "1. Ensure all Firebase config files are set up locally"
echo "2. Review docs/SECURITY_SETUP.md for detailed instructions"
echo "3. Run 'git status' to verify no sensitive files are staged"
echo "4. Safe to commit and push to GitHub!"
echo ""
