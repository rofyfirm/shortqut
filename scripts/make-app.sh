#!/bin/bash
# Membangun Shortqut.app (release) dari Swift Package.
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release

APP="build/Shortqut.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/Shortqut" "$APP/Contents/MacOS/Shortqut"

mkdir -p "$APP/Contents/Resources"
if [ ! -f "Assets/AppIcon.icns" ]; then
    ./scripts/make-icon.sh
fi
cp "Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Shortqut</string>
    <key>CFBundleDisplayName</key>
    <string>Shortqut</string>
    <key>CFBundleExecutable</key>
    <string>Shortqut</string>
    <key>CFBundleIdentifier</key>
    <string>com.shortqut.app</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.3.0</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc signing biasa menghasilkan requirement berbasis cdhash yang berubah di setiap build,
# sehingga izin Aksesibilitas yang sudah diberikan dianggap usang oleh macOS.
# Requirement berbasis bundle identifier tetap stabil antar build.
codesign --force --sign - --identifier com.shortqut.app \
    -r='designated => identifier "com.shortqut.app"' "$APP"

echo "Selesai: $APP"
