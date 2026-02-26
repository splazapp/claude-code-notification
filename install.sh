#!/bin/bash
# ClaudeCode Tap install — compile Swift notifier and build .app bundle
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/ClaudeCodeTap.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
BINARY="claudecode-tap"

echo "==> Compiling notifier.swift …"
xcrun swiftc "$SCRIPT_DIR/notifier.swift" \
    -o "$SCRIPT_DIR/$BINARY" \
    -framework AppKit \
    -framework UserNotifications \
    -O

echo "==> Building ClaudeCodeTap.app bundle …"
rm -rf "$APP_DIR"
mkdir -p "$MACOS"
mv "$SCRIPT_DIR/$BINARY" "$MACOS/$BINARY"

cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.claudecode.tap</string>
    <key>CFBundleName</key>
    <string>ClaudeCode Tap</string>
    <key>CFBundleExecutable</key>
    <string>claudecode-tap</string>
    <key>CFBundleVersion</key>
    <string>2.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
PLIST

# Copy icon if available
ICON_SRC="$SCRIPT_DIR/AppIcon.png"
if [ -f "$ICON_SRC" ]; then
    mkdir -p "$CONTENTS/Resources"
    cp "$ICON_SRC" "$CONTENTS/Resources/AppIcon.png"
    echo "==> Icon copied."
fi

echo "==> Code signing …"
codesign --force --deep --sign - "$APP_DIR"

echo "==> Done! ClaudeCodeTap.app built at: $APP_DIR"
echo ""
echo "First run: macOS will ask for notification permission."
echo "Test with:"
echo "  $MACOS/$BINARY --title 'Test' --subtitle 'hello world'"
