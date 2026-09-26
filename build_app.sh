#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR/VitalsDeck"

echo "==> Building VitalsDeck (Release)..."
swift build -c release

APP_NAME="VitalsDeck.app"
APP_DIR="$DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Creating macOS App Bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp ".build/release/VitalsDeck" "$MACOS_DIR/VitalsDeck"
chmod +x "$MACOS_DIR/VitalsDeck"

# Copy Icon if exists
if [ -f "$DIR/VitalsDeck/AppIcon.icns" ]; then
    cp "$DIR/VitalsDeck/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Create Info.plist
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>VitalsDeck</string>
    <key>CFBundleIdentifier</key>
    <string>com.kodzy.VitalsDeck</string>
    <key>CFBundleName</key>
    <string>Vitals Deck</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Sign app bundle locally
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "==> Successfully created $APP_NAME at $DIR"
