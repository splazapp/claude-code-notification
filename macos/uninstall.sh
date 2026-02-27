#!/bin/bash
# ClaudeCodeNotification — Uninstall Script
set -euo pipefail

INSTALL_DIR="$HOME/.claude/claudecode-notification"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "=== ClaudeCodeNotification Uninstaller ==="
echo ""
echo "This will remove:"
echo "  • $INSTALL_DIR"
echo "  • Claude Code hooks from $SETTINGS_FILE"
echo ""

# ─── 二次确认 ───
read -r -p "Are you sure you want to uninstall? [y/N] " confirm
case "$confirm" in
    [yY][eE][sS]|[yY]) ;;
    *)
        echo "Aborted."
        exit 0
        ;;
esac
echo ""

# ─── 移除安装目录 ───
if [ -d "$INSTALL_DIR" ]; then
    echo "==> Removing $INSTALL_DIR …"
    rm -rf "$INSTALL_DIR"
    echo "    Done."
else
    echo "==> Install dir not found, skipping."
fi

# 同时清理旧版本目录（如果还存在）
for old in "$HOME/.claude/claudecode-tap" "$HOME/.claude/ccnotify"; do
    if [ -d "$old" ]; then
        echo "==> Removing legacy dir $old …"
        rm -rf "$old"
        echo "    Done."
    fi
done

# ─── 从 settings.json 移除 hooks ───
if [ -f "$SETTINGS_FILE" ]; then
    echo "==> Removing hooks from $SETTINGS_FILE …"
    /usr/bin/python3 - "$SETTINGS_FILE" << 'PYTHON'
import json, sys, os

settings_path = sys.argv[1]
patterns = ["claudecode-notification", "claudecode-tap", "ccnotify"]

with open(settings_path, 'r') as f:
    settings = json.load(f)

hooks = settings.get("hooks", {})
for event in list(hooks.keys()):
    entries = hooks[event]
    if isinstance(entries, list):
        for entry in entries:
            if isinstance(entry, dict) and "hooks" in entry:
                entry["hooks"] = [
                    h for h in entry["hooks"]
                    if not any(
                        p in h.get("command", "")
                        for p in patterns
                        if isinstance(h, dict)
                    )
                ]
        hooks[event] = [e for e in entries if e.get("hooks")]
        if not hooks[event]:
            del hooks[event]

settings["hooks"] = hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')

print("    settings.json updated.")
PYTHON
else
    echo "==> settings.json not found, skipping."
fi

echo ""
echo "==> Uninstall complete!"
echo ""
echo "Note: macOS notification permission for ClaudeCodeNotification remains."
echo "To remove it: System Settings → Notifications → ClaudeCodeNotification → Remove"
