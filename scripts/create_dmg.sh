#!/bin/bash
# Create BillBuddy.dmg for macOS distribution
set -e

APP_PATH="build/macos/Build/Products/Release/billbuddy.app"
DMG_NAME="billbuddy-macos-1.0.0.dmg"
DMG_DIR="output"

mkdir -p "$DMG_DIR"

# Use create-dmg if available, otherwise fallback to hdiutil
if command -v create-dmg &>/dev/null; then
  create-dmg \
    --volname "BillBuddy" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "billbuddy.app" 175 190 \
    --hide-extension "billbuddy.app" \
    --app-drop-link 425 190 \
    "$DMG_DIR/$DMG_NAME" \
    "$APP_PATH"
else
  # Fallback: create a read-only DMG manually
  DMG_TMP="$(mktemp -d)"
  cp -R "$APP_PATH" "$DMG_TMP/"
  ln -s /Applications "$DMG_TMP/Applications"
  hdiutil create -volname "BillBuddy" -srcfolder "$DMG_TMP" \
    -ov -format UDZO "$DMG_DIR/$DMG_NAME"
  rm -rf "$DMG_TMP"
fi

echo "✅ DMG created: $DMG_DIR/$DMG_NAME"
