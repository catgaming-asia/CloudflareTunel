#!/usr/bin/env bash
# Builds build/CloudflareTunnel.app (release), signed ad-hoc (or CLOUDFLARETUNNEL_SIGN_IDENTITY when set).
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

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Cloudflare Tunnel</string>
    <key>CFBundleDisplayName</key><string>Cloudflare Tunnel</string>
    <key>CFBundleIdentifier</key><string>asia.catgaming.cloudflaretunnel</string>
    <key>CFBundleExecutable</key><string>CloudflareTunnel</string>
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

SIGN_IDENTITY="${CLOUDFLARETUNNEL_SIGN_IDENTITY:--}"
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP ($VERSION build $BUILD_NUMBER)"
