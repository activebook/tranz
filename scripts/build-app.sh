#!/usr/bin/env bash
#
# Builds the Tranz release binary and assembles a runnable .app bundle.
#
# Usage: ./scripts/build-app.sh
# Output: build/Tranz.app  (open it with `open build/Tranz.app`)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Tranz"
BUNDLE_DIR="build/${APP_NAME}.app"

echo "▶ Building release binary (Universal 2: arm64 + x86_64)…"
# Note: in a sandboxed shell (e.g. some CI/agent environments), SwiftPM's own
# `sandbox-exec` can be blocked. If you hit "sandbox_apply: Operation not permitted",
# append `--disable-sandbox` to the command below.
swift build -c release --disable-sandbox --arch arm64 --arch x86_64

echo "▶ Locating compiled binary…"
if [ -f ".build/apple/Products/Release/${APP_NAME}" ]; then
    BINARY_PATH=".build/apple/Products/Release/${APP_NAME}"
elif [ -f ".build/release/${APP_NAME}" ]; then
    BINARY_PATH=".build/release/${APP_NAME}"
else
    echo "❌ Error: Could not locate built binary for ${APP_NAME}." >&2
    exit 1
fi

echo "▶ Assembling .app bundle…"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS" "$BUNDLE_DIR/Contents/Resources"

cp "$BINARY_PATH" "$BUNDLE_DIR/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$BUNDLE_DIR/Contents/Resources/AppIcon.icns"
fi
cp "Resources/menuBarIcon.png" "$BUNDLE_DIR/Contents/Resources/menuBarIcon.png"
cp "Resources/menuBarIcon@2x.png" "$BUNDLE_DIR/Contents/Resources/menuBarIcon@2x.png"

echo "▶ Ad-hoc code signing…"
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "▶ Verifying binary architecture…"
lipo -info "$BUNDLE_DIR/Contents/MacOS/${APP_NAME}"

echo "✅ Built $BUNDLE_DIR (Universal: arm64 + x86_64)"
echo "   Launch with: open \"$BUNDLE_DIR\""
