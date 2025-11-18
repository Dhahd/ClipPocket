#!/bin/bash

# ClipPocket GitHub Release Build Script
# Creates a distributable DMG for GitHub releases

set -e

echo "🚀 Building ClipPocket for GitHub Release..."
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build
rm -f ClipPocket-Installer.dmg

# Build with proper settings for distribution
echo "🔨 Building app..."
xcodebuild -scheme ClipPocket \
    -configuration Release \
    -derivedDataPath build \
    clean build

APP_PATH="build/Build/Products/Release/ClipPocket.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Could not find built app"
    exit 1
fi

echo "✅ Build completed successfully!"

# Check for Developer ID
echo ""
echo "🔍 Checking for Developer ID certificate..."
DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | cut -d'"' -f2)

if [ -n "$DEVELOPER_ID" ]; then
    echo "✅ Found: $DEVELOPER_ID"
    echo "📝 Signing app..."

    # Sign the app
    codesign --deep --force --verify --verbose \
        --sign "$DEVELOPER_ID" \
        --options runtime \
        --entitlements ClipPocket/ClipPocket.entitlements \
        "$APP_PATH"

    echo "✅ App signed successfully!"

    # Verify signature
    echo "🔍 Verifying signature..."
    codesign --verify --deep --strict --verbose=2 "$APP_PATH"
    echo "✅ Signature verified!"
else
    echo "⚠️  No Developer ID certificate found"
    echo "   App will be unsigned - users may see security warnings"
    echo ""
    echo "To get a Developer ID certificate:"
    echo "  1. Join Apple Developer Program: https://developer.apple.com/programs/"
    echo "  2. Create a Developer ID certificate in Xcode"
    echo "  3. Re-run this script"
    echo ""
    read -p "Continue without signing? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create DMG
echo ""
echo "📦 Creating DMG installer..."

DMG_DIR="build/dmg"
mkdir -p "$DMG_DIR"

# Copy the app
cp -R "$APP_PATH" "$DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_DIR/Applications"

# Create README
cat > "$DMG_DIR/README.txt" << 'EOF'
ClipPocket - Your Smart Clipboard Manager

Installation:
1. Drag ClipPocket.app to the Applications folder
2. Open ClipPocket from your Applications folder
3. If you see a security warning:
   - Go to System Settings > Privacy & Security
   - Click "Open Anyway" next to the ClipPocket warning
   - Or run this in Terminal:
     xattr -cr /Applications/ClipPocket.app
4. Follow the onboarding wizard to grant necessary permissions
5. Use ⌘⇧V (Cmd+Shift+V) to open ClipPocket anytime

Features:
• Smart clipboard history with automatic saving
• Type detection (URLs, colors, code, files, images, JSON, etc.)
• File copying from Finder
• Pin favorites
• Quick search
• Privacy mode with incognito and excluded apps
• Keyboard shortcuts
• Auto updates
• Text transformations
• Export/import history
• Optional history size limit

For support: shaneendhahd@gmail.com
EOF

# Create the DMG
hdiutil create -volname "ClipPocket Installer" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "ClipPocket-Installer.dmg"

# Clean up
rm -rf "$DMG_DIR"

echo "✅ DMG created successfully!"

# Sign DMG if we have a Developer ID
if [ -n "$DEVELOPER_ID" ]; then
    echo ""
    echo "📝 Signing DMG..."
    codesign --sign "$DEVELOPER_ID" "ClipPocket-Installer.dmg"
    echo "✅ DMG signed!"
fi

# Display results
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 GitHub Release Build Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📦 Installer: ClipPocket-Installer.dmg"
echo "📏 Size: $(du -h ClipPocket-Installer.dmg | cut -f1)"
echo "📍 Location: $(pwd)/ClipPocket-Installer.dmg"
echo "🔐 Signed: $([ -n "$DEVELOPER_ID" ] && echo "Yes ✅" || echo "No ⚠️")"
echo ""
echo "SHA256: $(shasum -a 256 ClipPocket-Installer.dmg | cut -d' ' -f1)"
echo ""

if [ -z "$DEVELOPER_ID" ]; then
    echo "⚠️  IMPORTANT: App is not signed"
    echo ""
    echo "Add this to your GitHub release notes:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "### Installation Note"
    echo "If you see a security warning, run this command:"
    echo "\`\`\`bash"
    echo "xattr -cr /Applications/ClipPocket.app"
    echo "\`\`\`"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

echo "Next steps:"
echo "  1. Test the DMG on a clean Mac"
echo "  2. Upload to GitHub Releases"
echo "  3. Add release notes with version changes"
echo ""

echo "✅ Ready for distribution!"
