#!/bin/bash
# Membuat Assets/AppIcon.icns dari scripts/make-icon.swift.
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p Assets
swift scripts/make-icon.swift Assets/icon-1024.png

ICONSET="Assets/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Assets/icon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Assets/icon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o Assets/AppIcon.icns
rm -rf "$ICONSET"

echo "Selesai: Assets/AppIcon.icns"
