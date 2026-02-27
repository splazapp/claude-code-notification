# ClaudeCodeNotification — Windows Remote Installer
# One-line install: irm https://raw.githubusercontent.com/splazapp/claude-code-notification/main/windows/install-remote.ps1 | iex
#
# Environment variables:
#   $env:VERSION = "v2.3.0"  — pin to a specific release (default: latest)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Repo        = "splazapp/claude-code-notification"
$ExeName     = "claudecode-notification.exe"
$ScriptName  = "claudecode-notification.ps1"
$InstallDir  = "$env:APPDATA\claudecode-notification"
$SettingsFile = "$HOME\.claude\settings.json"
$AppId       = "ClaudeCodeNotification"

Write-Host ""
Write-Host "=== ClaudeCodeNotification Windows Remote Installer ===" -ForegroundColor Cyan
Write-Host ""

# ─── Pre-flight checks ───

# Windows 10 1809+ (build 17763)
$build = [System.Environment]::OSVersion.Version.Build
if ($build -lt 17763) {
    Write-Host "Error: Windows 10 1809 (build 17763) or later required. Your build: $build" -ForegroundColor Red
    exit 1
}

# PowerShell 5.1+
if ($PSVersionTable.PSVersion.Major -lt 5 -or
    ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -lt 1)) {
    Write-Host "Error: PowerShell 5.1+ required." -ForegroundColor Red
    exit 1
}

# Claude Code installed
if (-not (Test-Path "$HOME\.claude")) {
    Write-Host "Error: ~/.claude/ not found. Please install Claude Code first." -ForegroundColor Red
    exit 1
}

# Node.js (needed for hooks setup)
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Node.js is required (included with Claude Code)." -ForegroundColor Red
    exit 1
}

# ─── Determine version ───

$ReleaseTag = if ($env:VERSION) { $env:VERSION } else { "latest" }

if ($ReleaseTag -ne "latest") {
    Write-Host "==> Using specified version: $ReleaseTag"
} else {
    Write-Host "==> Downloading latest release ..."
}

# ─── Temporary directory with cleanup ───

$TmpDir = Join-Path $env:TEMP "claudecode-notification-install-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

try {
    # ─── Download exe from GitHub Releases ───

    if ($ReleaseTag -eq "latest") {
        $ExeUrl = "https://github.com/$Repo/releases/latest/download/$ExeName"
    } else {
        $ExeUrl = "https://github.com/$Repo/releases/download/$ReleaseTag/$ExeName"
    }

    Write-Host "    Fetching $ExeName ..."
    try {
        Invoke-WebRequest -Uri $ExeUrl -OutFile (Join-Path $TmpDir $ExeName) -UseBasicParsing
    } catch {
        Write-Host "Error: Failed to download $ExeName from $ExeUrl" -ForegroundColor Red
        Write-Host "       $_" -ForegroundColor Red
        exit 1
    }

    # ─── Download hook script from raw.githubusercontent.com ───

    if ($ReleaseTag -eq "latest") {
        $ScriptUrl = "https://raw.githubusercontent.com/$Repo/main/windows/$ScriptName"
    } else {
        $ScriptUrl = "https://raw.githubusercontent.com/$Repo/$ReleaseTag/windows/$ScriptName"
    }

    Write-Host "    Fetching $ScriptName ..."
    try {
        Invoke-WebRequest -Uri $ScriptUrl -OutFile (Join-Path $TmpDir $ScriptName) -UseBasicParsing
    } catch {
        Write-Host "Error: Failed to download $ScriptName from $ScriptUrl" -ForegroundColor Red
        Write-Host "       $_" -ForegroundColor Red
        exit 1
    }

    # ─── Install files ───

    Write-Host "==> Installing to $InstallDir ..."
    if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

    Copy-Item (Join-Path $TmpDir $ScriptName) (Join-Path $InstallDir $ScriptName)
    Copy-Item (Join-Path $TmpDir $ExeName)    (Join-Path $InstallDir $ExeName)

    Write-Host "    Copied $ScriptName"
    Write-Host "    Copied $ExeName"

    # ─── Register Toast AUMID ───

    Write-Host "==> Registering Toast AppUserModelId ..."
    $RegPath = "HKCU:\SOFTWARE\Classes\AppUserModelId\$AppId"
    if (-not (Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
    Set-ItemProperty -Path $RegPath -Name "DisplayName" -Value $AppId
    Write-Host "    Registered: $AppId"

    # ─── Configure Claude Code hooks ───

    Write-Host "==> Configuring Claude Code hooks ..."

    $SettingsDir = Split-Path $SettingsFile
    if (-not (Test-Path $SettingsDir)) { New-Item -ItemType Directory -Force -Path $SettingsDir | Out-Null }
    if (-not (Test-Path $SettingsFile)) { '{}' | Set-Content $SettingsFile -Encoding UTF8 }

    $HookScript = Join-Path $InstallDir $ScriptName

    $TmpJs = Join-Path $env:TEMP "claudecode-notification-setup.js"
    @'
const fs = require('fs');
const settingsPath = process.argv[2];
const hookScript   = process.argv[3];
const psPrefix     = 'powershell.exe -ExecutionPolicy Bypass -NonInteractive -File';

let settings = {};
try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8')); } catch {}
settings.hooks = settings.hooks || {};

for (const event of ['UserPromptSubmit', 'Stop', 'Notification']) {
    const fullCmd   = psPrefix + ' "' + hookScript + '" ' + event;
    const hookEntry = { hooks: [{ type: 'command', command: fullCmd }] };
    const existing  = settings.hooks[event] || [];
    const already   = existing.some(e =>
        e.hooks && e.hooks.some(h => h.command && h.command.includes('claudecode-notification.ps1'))
    );
    if (!already) existing.push(hookEntry);
    settings.hooks[event] = existing;
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n', 'utf8');
console.log('    settings.json updated.');
'@ | Set-Content $TmpJs -Encoding UTF8

    node $TmpJs $SettingsFile $HookScript
    Remove-Item $TmpJs -Force -ErrorAction SilentlyContinue

    # ─── Done ───

    Write-Host ""
    Write-Host "==> Installation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Hooks registered for: UserPromptSubmit, Stop, Notification"
    Write-Host "Install dir: $InstallDir"
    Write-Host ""
    Write-Host "On first notification, Windows may ask for notification permission." -ForegroundColor Yellow
    Write-Host "If notifications don't appear: Settings -> System -> Notifications -> ClaudeCodeNotification -> On"

} finally {
    # ─── Cleanup temp directory ───
    Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
