#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

VERSION="1.2.0"

echo "==> Building VitalsDeck app bundle (v${VERSION})..."
./build_app.sh

APP_BUNDLE="$DIR/VitalsDeck.app"
DMG_NAME="VitalsDeck-v${VERSION}.dmg"
ZIP_NAME="VitalsDeck-v${VERSION}.zip"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE not found!"
    exit 1
fi

echo "==> Creating ZIP archive: $ZIP_NAME..."
rm -f "$DIR/$ZIP_NAME"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$DIR/$ZIP_NAME"

echo "==> Creating DMG image: $DMG_NAME..."
rm -f "$DIR/$DMG_NAME"
STAGING_DIR=$(mktemp -d /tmp/vitalsdeck_dmg_staging.XXXXXX)
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -volname "VitalsDeck" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DIR/$DMG_NAME"
rm -rf "$STAGING_DIR"

echo "==> Release packaging complete:"
ls -lh "$DIR/$DMG_NAME" "$DIR/$ZIP_NAME"
