#!/bin/bash
# Membuat build/Shortqut-<versi>.dmg berisi Shortqut.app dan shortcut ke folder Applications.
#
# Opsional (untuk distribusi tanpa peringatan Gatekeeper):
#   SIGN_IDENTITY="Developer ID Application: Nama (TEAMID)" ./scripts/make-dmg.sh
#   SIGN_IDENTITY=... NOTARY_PROFILE="shortqut-notary" ./scripts/make-dmg.sh
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/make-app.sh

APP="build/Shortqut.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="build/Shortqut-$VERSION.dmg"
STAGING="build/dmg-staging"

if [ -n "${SIGN_IDENTITY:-}" ]; then
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "Shortqut" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

if [ -n "${SIGN_IDENTITY:-}" ]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi

if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
fi

echo "Selesai: $DMG"
