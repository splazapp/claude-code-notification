#!/bin/bash
# ClaudeCodeNotification — Local Install Script
# Installs prebuilt .app or builds from source, then configures Claude Code hooks
# For one-line remote install, use: curl -fsSL https://raw.githubusercontent.com/splazapp/claude-code-notification/main/install-remote.sh | bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ClaudeCodeNotification"
HOOK_SCRIPT="claudecode-notification.sh"
INSTALL_DIR="$HOME/.claude/claudecode-notification"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "=== ClaudeCodeNotification Installer ==="
echo ""

# ─── Locate or build the .app ───
APP_PATH=""
for candidate in \
    "$SCRIPT_DIR/dist/$APP_NAME.app" \
    "$SCRIPT_DIR/$APP_NAME.app"; do
    if [ -d "$candidate" ]; then
        APP_PATH="$candidate"
        break
    fi
done

if [ -z "$APP_PATH" ]; then
    echo "No prebuilt $APP_NAME.app found. Building from source …"
    echo ""
    if ! command -v xcrun &>/dev/null; then
        echo "Error: Xcode Command Line Tools required." >&2
        echo "Install with: xcode-select --install" >&2
        exit 1
    fi
    bash "$SCRIPT_DIR/build.sh"
    APP_PATH="$SCRIPT_DIR/dist/$APP_NAME.app"
    if [ ! -d "$APP_PATH" ]; then
        echo "Error: Build failed — $APP_NAME.app not found." >&2
        exit 1
    fi
fi

echo "Using: $APP_PATH"
echo ""

# ─── Install files ───
echo "==> Installing to $INSTALL_DIR …"

# Clean old installation (including old name)
OLD_INSTALL="$HOME/.claude/claudecode-tap"
if [ -d "$OLD_INSTALL" ]; then
    echo "    Removing old claudecode-tap installation …"
    rm -rf "$OLD_INSTALL"
fi

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

cp "$SCRIPT_DIR/$HOOK_SCRIPT" "$INSTALL_DIR/$HOOK_SCRIPT"
chmod +x "$INSTALL_DIR/$HOOK_SCRIPT"
cp -R "$APP_PATH" "$INSTALL_DIR/$APP_NAME.app"

echo "    Copied $HOOK_SCRIPT"
echo "    Copied $APP_NAME.app"

# ─── Patch settings.json ───
echo "==> Configuring Claude Code hooks …"

HOOK_CMD="$INSTALL_DIR/$HOOK_SCRIPT"

/usr/bin/python3 - "$SETTINGS_FILE" "$HOOK_CMD" << 'PYTHON'
import json, sys, os

settings_path = sys.argv[1]
hook_cmd = sys.argv[2]

# Load existing settings or create new
if os.path.exists(settings_path):
    with open(settings_path, 'r') as f:
        settings = json.load(f)
else:
    settings = {}

hooks = settings.setdefault("hooks", {})

# Remove old claudecode-tap hooks if present
old_pattern = "claudecode-tap"
for event in list(hooks.keys()):
    entries = hooks[event]
    if isinstance(entries, list):
        for entry in entries:
            if isinstance(entry, dict) and "hooks" in entry:
                entry["hooks"] = [
                    h for h in entry["hooks"]
                    if not (isinstance(h, dict) and old_pattern in h.get("command", ""))
                ]
        # Remove empty entries
        hooks[event] = [e for e in entries if e.get("hooks")]
        if not hooks[event]:
            del hooks[event]

# Add new hooks
for event in ["UserPromptSubmit", "Stop", "Notification"]:
    hook_entry = {
        "hooks": [{
            "type": "command",
            "command": f"{hook_cmd} {event}"
        }]
    }
    existing = hooks.get(event, [])
    # Check if already present
    already = any(
        hook_cmd in h.get("command", "")
        for entry in existing if isinstance(entry, dict)
        for h in entry.get("hooks", []) if isinstance(h, dict)
    )
    if not already:
        existing.append(hook_entry)
    hooks[event] = existing

settings["hooks"] = hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')

print("    settings.json updated.")
PYTHON

echo ""
echo "==> Installation complete!"
echo ""
echo "Hooks registered for: UserPromptSubmit, Stop, Notification"
echo "Install dir: $INSTALL_DIR"
echo ""
echo "On first notification, macOS will ask for permission — click Allow."
