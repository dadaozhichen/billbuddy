#!/bin/bash
# Create BillBuddy .deb package for Linux
set -e

VERSION="${VERSION:-1.0.0}"
PKG_NAME="billbuddy"
BUILD_DIR="build/linux/x64/release/bundle"
OUTPUT_DIR="output"

mkdir -p "$OUTPUT_DIR/$PKG_NAME-$VERSION/DEBIAN"
mkdir -p "$OUTPUT_DIR/$PKG_NAME-$VERSION/usr/bin"
mkdir -p "$OUTPUT_DIR/$PKG_NAME-$VERSION/usr/share/applications"
mkdir -p "$OUTPUT_DIR/$PKG_NAME-$VERSION/usr/share/$PKG_NAME"
mkdir -p "$OUTPUT_DIR/$PKG_NAME-$VERSION/usr/share/icons/hicolor/256x256/apps"

# Control file
cat > "$OUTPUT_DIR/$PKG_NAME-$VERSION/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Maintainer: zhuhkblog.cn
Description: BillBuddy - Cross-platform personal bookkeeping app
 Track expenses and income across multiple currencies and ledgers.
EOF

# Copy bundle
cp -r "$BUILD_DIR"/* "$OUTPUT_DIR/$PKG_NAME-$VERSION/usr/share/$PKG_NAME/"

# Symlink
cat > "$OUTPUT_DIR/$PKG_NAME-$VERSION/usr/bin/billbuddy" <<'SCRIPT'
#!/bin/bash
/usr/share/billbuddy/billbuddy "$@"
SCRIPT
chmod +x "$OUTPUT_DIR/$PKG_NAME-$VERSION/usr/bin/billbuddy"

# Desktop entry
cat > "$OUTPUT_DIR/$PKG_NAME-$VERSION/usr/share/applications/billbuddy.desktop" <<EOF
[Desktop Entry]
Name=BillBuddy
Comment=Personal bookkeeping app
Exec=/usr/bin/billbuddy
Icon=billbuddy
Terminal=false
Type=Application
Categories=Office;Finance;
EOF

# Icon (use the existing PNG)
cp assets/icon/icon.png "$OUTPUT_DIR/$PKG_NAME-$VERSION/usr/share/icons/hicolor/256x256/apps/billbuddy.png"

# Build .deb
dpkg-deb --build "$OUTPUT_DIR/$PKG_NAME-$VERSION"

echo "✅ .deb created: $OUTPUT_DIR/${PKG_NAME}-${VERSION}.deb"
