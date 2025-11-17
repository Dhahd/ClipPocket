#!/bin/bash

# ClipPocket Installer Creation Script
# This script builds the app and creates a DMG installer

set -e  # Exit on error

echo "🚀 Building ClipPocket..."
echo ""

# Check GitHub release status first (optional, but recommended)
if [ -f "./check-github-release.sh" ]; then
    echo "🔍 Checking GitHub release status..."
    if ./check-github-release.sh; then
        echo ""
    else
        echo ""
        echo "⚠️  Warning: GitHub release check failed"
        echo "   The update checker may not work properly"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Build cancelled"
            exit 1
        fi
    fi
fi

# Clean build folder
rm -rf build
rm -rf ClipPocket-Installer.dmg

# Build the app in Release mode
xcodebuild -scheme ClipPocket \
    -configuration Release \
    -derivedDataPath build \
    clean build

echo "✅ Build completed successfully!"

# Find the built app
APP_PATH="build/Build/Products/Release/ClipPocket.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Could not find built app at $APP_PATH"
    exit 1
fi

echo "📦 Creating DMG installer..."

# Create a temporary directory for DMG contents
DMG_DIR="build/dmg"
mkdir -p "$DMG_DIR"

# Copy the app to the DMG directory
cp -R "$APP_PATH" "$DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_DIR/Applications"

# Create a README file
cat > "$DMG_DIR/README.txt" << 'EOF'
ClipPocket - Your Smart Clipboard Manager

Installation:
1. Drag ClipPocket.app to the Applications folder
2. Open ClipPocket from your Applications folder
3. Follow the onboarding wizard to grant necessary permissions
4. Use ⌘⇧V (Cmd+Shift+V) to open ClipPocket anytime

Features:
• Smart clipboard history - Automatically saves everything you copy
• Type detection - Recognizes URLs, colors, code, files, images, JSON, and more
• File copying - Copy and paste file references directly from Finder
• Pin favorites - Keep frequently used items at your fingertips
• Quick search - Find anything instantly with powerful search
• Privacy first - All data stays local on your Mac, with incognito mode
• Keyboard shortcuts - Access with ⌘⇧V (Cmd+Shift+V)
• Auto updates - Automatic update checking with one-click installation
• Text transformations and quick actions
• Export/import clipboard history

For support, contact: shaneendhahd@gmail.com
EOF

# Create the DMG
echo "Creating DMG file..."
hdiutil create -volname "ClipPocket Installer" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "ClipPocket-Installer.dmg"

# Clean up
rm -rf "$DMG_DIR"

echo "✅ DMG created successfully: ClipPocket-Installer.dmg"
echo ""
echo "📦 Installer location: $(pwd)/ClipPocket-Installer.dmg"
echo "📏 File size: $(du -h ClipPocket-Installer.dmg | cut -f1)"
echo ""
echo "🎉 Done! You can now distribute ClipPocket-Installer.dmg"
