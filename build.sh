#!/bin/bash
# ClaudeCodeNotification — Developer Build Script
# Compiles universal binary, creates .app bundle, outputs to dist/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
APP_NAME="ClaudeCodeNotification"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
BINARY="claudecode-notification"
BUNDLE_ID="com.splat.claudecode.notification"
SWIFT_SRC="$SCRIPT_DIR/notifier.swift"
ICON_SRC="$SCRIPT_DIR/AppIcon.png"

SIGN_IDENTITY="-"  # ad-hoc by default
DO_NOTARIZE=false

# ─── Parse args ───
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sign)
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        --notarize)
            DO_NOTARIZE=true
            shift
            ;;
        -h|--help)
            echo "Usage: bash build.sh [--sign \"Developer ID Application: ...\"] [--notarize]"
            echo ""
            echo "Options:"
            echo "  --sign IDENTITY   Code sign with Developer ID (default: ad-hoc)"
            echo "  --notarize        Notarize after signing (requires Developer ID)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if $DO_NOTARIZE && [ "$SIGN_IDENTITY" = "-" ]; then
    echo "Error: --notarize requires --sign with a Developer ID" >&2
    exit 1
fi

# ─── Check prerequisites ───
if ! command -v xcrun &>/dev/null; then
    echo "Error: Xcode Command Line Tools required. Run: xcode-select --install" >&2
    exit 1
fi

# ─── Compile universal binary (arm64 + x86_64, macOS 13+) ───
echo "==> Compiling $BINARY (universal binary) …"
TEMP_ARM="$(mktemp)"
TEMP_X86="$(mktemp)"
trap 'rm -f "$TEMP_ARM" "$TEMP_X86"' EXIT

xcrun swiftc "$SWIFT_SRC" \
    -o "$TEMP_ARM" \
    -target arm64-apple-macos13 \
    -framework AppKit \
    -framework UserNotifications \
    -O

xcrun swiftc "$SWIFT_SRC" \
    -o "$TEMP_X86" \
    -target x86_64-apple-macos13 \
    -framework AppKit \
    -framework UserNotifications \
    -O

mkdir -p "$DIST_DIR"
lipo -create "$TEMP_ARM" "$TEMP_X86" -output "$DIST_DIR/$BINARY"
echo "    Universal binary: $(file "$DIST_DIR/$BINARY" | sed 's/.*: //')"

# ─── Build .app bundle ───
echo "==> Building $APP_NAME.app …"
rm -rf "$APP_DIR"
mkdir -p "$MACOS"
mv "$DIST_DIR/$BINARY" "$MACOS/$BINARY"

cat > "$CONTENTS/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$BINARY</string>
    <key>CFBundleVersion</key>
    <string>2.0</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
PLIST

if [ -f "$ICON_SRC" ]; then
    mkdir -p "$CONTENTS/Resources"
    cp "$ICON_SRC" "$CONTENTS/Resources/AppIcon.png"
    echo "    Icon copied."
fi

# ─── Code sign ───
echo "==> Code signing (identity: $SIGN_IDENTITY) …"
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"

# ─── Notarize (optional) ───
if $DO_NOTARIZE; then
    echo "==> Creating zip for notarization …"
    ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
    ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
    echo "==> Submitting for notarization …"
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "notarytool" --wait
    echo "==> Stapling …"
    xcrun stapler staple "$APP_DIR"
    # Re-create zip with stapled app
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
    echo "==> Notarized zip: $ZIP_PATH"
fi

# ─── Create distribution zip ───
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
if [ ! -f "$ZIP_PATH" ]; then
    ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
fi

echo ""
echo "==> Done!"
echo "    App:  $APP_DIR"
echo "    Zip:  $ZIP_PATH"
echo ""
echo "Test with:"
echo "  open -n \"$APP_DIR\" --args --title 'Test' --subtitle 'hello world'"
