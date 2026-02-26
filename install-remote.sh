#!/bin/bash
# ClaudeCodeNotification — Remote Installer
# One-line install: curl -fsSL https://raw.githubusercontent.com/splazapp/claude-code-notification/main/install-remote.sh | bash
#
# Environment variables:
#   VERSION=v2.0  — pin to a specific release (default: latest)
set -euo pipefail

REPO="splazapp/claude-code-notification"
APP_NAME="ClaudeCodeNotification"
HOOK_SCRIPT="claudecode-notification.sh"
INSTALL_DIR="$HOME/.claude/claudecode-notification"
SETTINGS_FILE="$HOME/.claude/settings.json"

# ─── Helpers ───

info()  { echo "  $*"; }
step()  { echo "==> $*"; }
fail()  { echo "Error: $*" >&2; exit 1; }

# ─── Pre-flight checks ───

echo ""
echo "=== ClaudeCodeNotification Remote Installer ==="
echo ""

# macOS only
[ "$(uname -s)" = "Darwin" ] || fail "This tool requires macOS."

# macOS 13+
macos_ver=$(sw_vers -productVersion)
macos_major=$(echo "$macos_ver" | cut -d. -f1)
[ "$macos_major" -ge 13 ] 2>/dev/null || fail "macOS 13 (Ventura) or later required. You have $macos_ver."

# Claude Code installed
[ -d "$HOME/.claude" ] || fail "~/.claude/ not found. Please install Claude Code first."

# curl available
command -v curl &>/dev/null || fail "curl is required but not found."

# unzip available
command -v unzip &>/dev/null || fail "unzip is required but not found."

# ─── Temporary directory with cleanup ───

TMPDIR_INSTALL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_INSTALL"' EXIT

# ─── Determine version ───

if [ -n "${VERSION:-}" ]; then
    TAG="$VERSION"
    step "Using specified version: $TAG"
else
    TAG="latest"
    step "Downloading latest release …"
fi

# ─── Download assets ───

# 1. Download zip (GitHub /releases/latest/download/ auto-redirects to newest tag)
if [ "$TAG" = "latest" ]; then
    ZIP_URL="https://github.com/$REPO/releases/latest/download/$APP_NAME.zip"
else
    ZIP_URL="https://github.com/$REPO/releases/download/$TAG/$APP_NAME.zip"
fi

info "Fetching $APP_NAME.zip …"
curl -fSL "$ZIP_URL" -o "$TMPDIR_INSTALL/$APP_NAME.zip" || fail "Failed to download $APP_NAME.zip from $ZIP_URL"

# 2. Download hook script from main branch (or tagged version)
if [ "$TAG" = "latest" ]; then
    SCRIPT_URL="https://raw.githubusercontent.com/$REPO/main/$HOOK_SCRIPT"
else
    SCRIPT_URL="https://raw.githubusercontent.com/$REPO/$TAG/$HOOK_SCRIPT"
fi

info "Fetching $HOOK_SCRIPT …"
curl -fSL "$SCRIPT_URL" -o "$TMPDIR_INSTALL/$HOOK_SCRIPT" || fail "Failed to download $HOOK_SCRIPT"

# ─── Extract and verify ───

step "Extracting …"
unzip -q "$TMPDIR_INSTALL/$APP_NAME.zip" -d "$TMPDIR_INSTALL"

# Verify .app structure
APP_BINARY="$TMPDIR_INSTALL/$APP_NAME.app/Contents/MacOS/claudecode-notification"
[ -f "$APP_BINARY" ] || fail "$APP_NAME.app is incomplete — binary not found."

# ─── Install files ───

step "Installing to $INSTALL_DIR …"

# Clean old installation (including legacy name)
OLD_INSTALL="$HOME/.claude/claudecode-tap"
if [ -d "$OLD_INSTALL" ]; then
    info "Removing old claudecode-tap installation …"
    rm -rf "$OLD_INSTALL"
fi

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

cp "$TMPDIR_INSTALL/$HOOK_SCRIPT" "$INSTALL_DIR/$HOOK_SCRIPT"
chmod +x "$INSTALL_DIR/$HOOK_SCRIPT"
cp -R "$TMPDIR_INSTALL/$APP_NAME.app" "$INSTALL_DIR/$APP_NAME.app"

info "Copied $HOOK_SCRIPT"
info "Copied $APP_NAME.app"

# ─── Register hooks in settings.json ───

step "Configuring Claude Code hooks …"

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

print("  settings.json updated.")
PYTHON

# ─── Done ───

echo ""
echo "==> Installation complete!"
echo ""
echo "Hooks registered for: UserPromptSubmit, Stop, Notification"
echo "Install dir: $INSTALL_DIR"
echo ""
echo "On first notification, macOS will ask for permission — click Allow."
