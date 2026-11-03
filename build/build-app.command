#!/usr/bin/env bash
# Builds build/CloudflareTunnel.app (release). Signed with a fixed Apple Development certificate when present, otherwise ad-hoc.
# Double-click in Finder or run from Terminal.
set -euo pipefail

OUT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$OUT_DIR/.." && pwd)"
cd "$ROOT"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="$OUT_DIR/CloudflareTunnel.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/CloudflareTunnel" "$APP/Contents/MacOS/CloudflareTunnel"

# App icon: Resources/AppIcon.png (1024px, drawn by tools/draw-icon.swift).
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Cloudflare Tunnel</string>
    <key>CFBundleDisplayName</key><string>Cloudflare Tunnel</string>
    <key>CFBundleIdentifier</key><string>asia.catgaming.cloudflaretunnel</string>
    <key>CFBundleExecutable</key><string>CloudflareTunnel</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# Version: VERSION (CFBundleShortVersionString), commit count (CFBundleVersion; no git → 1).
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION" 2>/dev/null || true)"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || true)"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"

# Default: the same Apple Development certificate as Local Server (by SHA-1). Override with CLOUDFLARETUNNEL_SIGN_IDENTITY.
SIGN_IDENTITY="${CLOUDFLARETUNNEL_SIGN_IDENTITY:-E154544B45E03CE74ADB793B98E77AF31F9BDC60}"
if security find-identity -v -p codesigning | grep -qF "$SIGN_IDENTITY"; then
    codesign --force --deep --options runtime --timestamp=none -s "$SIGN_IDENTITY" "$APP"
else
    echo "Signing ad-hoc: no codesigning identity $SIGN_IDENTITY. Set CLOUDFLARETUNNEL_SIGN_IDENTITY to use another one." >&2
    codesign --force --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"
codesign -dvv "$APP" 2>&1 | grep -E '^(Authority|Signature)' || true
echo "Built $APP ($VERSION build $BUILD_NUMBER)"
