# ClaudeCodeNotification - Windows Uninstall Script
# 移除通知器、注销 AUMID 并清理 Claude Code hooks
#
# Usage: .\uninstall.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstallDir   = "$env:APPDATA\claudecode-notification"
$SettingsFile = "$HOME\.claude\settings.json"
$AppId        = "ClaudeCodeNotification"
$RegPath      = "HKCU:\SOFTWARE\Classes\AppUserModelId\$AppId"

Write-Host "=== ClaudeCodeNotification Windows Uninstaller ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will remove:"
Write-Host "  • $InstallDir"
Write-Host "  • Registry: $RegPath"
Write-Host "  • Claude Code hooks from $SettingsFile"
Write-Host ""

# ─── 二次确认 ───
$confirm = Read-Host "Are you sure you want to uninstall? [y/N]"
if ($confirm -notmatch '^[yY]([eE][sS])?$') {
    Write-Host "Aborted."
    exit 0
}
Write-Host ""

# ─── 移除安装目录 ───
if (Test-Path $InstallDir) {
    Write-Host "==> Removing $InstallDir ..."
    Remove-Item $InstallDir -Recurse -Force
    Write-Host "    Done."
} else {
    Write-Host "==> Install dir not found, skipping."
}

# ─── 注销 Toast AUMID ───
if (Test-Path $RegPath) {
    Write-Host "==> Removing registry entry $RegPath ..."
    Remove-Item $RegPath -Recurse -Force
    Write-Host "    Done."
} else {
    Write-Host "==> Registry entry not found, skipping."
}

# ─── 清理 Claude Code hooks ───
if (Test-Path $SettingsFile) {
    Write-Host "==> Removing hooks from $SettingsFile ..."

    $jsCode = @"
const fs = require('fs');
const settingsPath = process.argv[1];
const pattern = 'claudecode-notification';

let settings = {};
try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8')); } catch { process.exit(0); }

const hooks = settings.hooks || {};
for (const event of Object.keys(hooks)) {
    const entries = hooks[event];
    if (!Array.isArray(entries)) continue;
    for (const entry of entries) {
        if (entry && Array.isArray(entry.hooks)) {
            entry.hooks = entry.hooks.filter(
                h => !(h && h.command && h.command.includes(pattern))
            );
        }
    }
    hooks[event] = entries.filter(e => e && Array.isArray(e.hooks) && e.hooks.length > 0);
    if (hooks[event].length === 0) delete hooks[event];
}

settings.hooks = hooks;
fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n', 'utf8');
console.log('    settings.json updated.');
"@

    node -e $jsCode $SettingsFile
} else {
    Write-Host "==> settings.json not found, skipping."
}

Write-Host ""
Write-Host "==> Uninstall complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Windows notification permission for ClaudeCodeNotification remains." -ForegroundColor Yellow
Write-Host "To remove it: Settings → System → Notifications → ClaudeCodeNotification → Off (then remove app)"
