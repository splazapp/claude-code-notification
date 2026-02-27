# ClaudeCodeNotification - Windows Install Script
# 安装通知器并注册 Claude Code hooks
#
# Usage: .\install.ps1
# Requires: Windows 10 1809+ (build 17763+), PowerShell 5.1+

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir  = "$env:APPDATA\claudecode-notification"
$SettingsFile = "$HOME\.claude\settings.json"
$AppId       = "ClaudeCodeNotification"

Write-Host "=== ClaudeCodeNotification Windows Installer ===" -ForegroundColor Cyan
Write-Host ""

# ─── 查找或构建 exe ───
$ExePath = ""
foreach ($candidate in @(
    (Join-Path $ScriptDir "dist\claudecode-notification.exe"),
    (Join-Path $ScriptDir "claudecode-notification.exe")
)) {
    if (Test-Path $candidate) { $ExePath = $candidate; break }
}

if (-not $ExePath) {
    # ─── 尝试从 GitHub Releases 下载 ───
    $Repo     = "splazapp/claude-code-notification"
    $ExeName  = "claudecode-notification.exe"
    $ReleaseTag = if ($env:VERSION) { $env:VERSION } else { "latest" }

    if ($ReleaseTag -eq "latest") {
        $DownloadUrl = "https://github.com/$Repo/releases/latest/download/$ExeName"
    } else {
        $DownloadUrl = "https://github.com/$Repo/releases/download/$ReleaseTag/$ExeName"
    }

    $DistDir = Join-Path $ScriptDir "dist"
    New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
    $DownloadDest = Join-Path $DistDir $ExeName

    try {
        Write-Host "Downloading $ExeName from GitHub Releases ..."
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadDest -UseBasicParsing
        $ExePath = $DownloadDest
        Write-Host "    Downloaded successfully."
    } catch {
        Write-Host "    Download failed: $_" -ForegroundColor Yellow
        Write-Host ""
    }
}

if (-not $ExePath) {
    # ─── 回退到源码编译 ───
    Write-Host "No prebuilt exe found. Building from source ..."
    Write-Host ""
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Host "Error: .NET SDK not found and download failed." -ForegroundColor Red
        Write-Host "Either check your network or install .NET 8 SDK:" -ForegroundColor Yellow
        Write-Host "  https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Yellow
        exit 1
    }
    & (Join-Path $ScriptDir "build.ps1")
    $ExePath = Join-Path $ScriptDir "dist\claudecode-notification.exe"
    if (-not (Test-Path $ExePath)) {
        Write-Host "Error: Build failed." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Using: $ExePath"
Write-Host ""

# ─── 安装文件 ───
Write-Host "==> Installing to $InstallDir ..."
if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

Copy-Item (Join-Path $ScriptDir "claudecode-notification.ps1") (Join-Path $InstallDir "claudecode-notification.ps1")
Copy-Item $ExePath (Join-Path $InstallDir "claudecode-notification.exe")

Write-Host "    Copied claudecode-notification.ps1"
Write-Host "    Copied claudecode-notification.exe"

# ─── 注册 Toast AUMID（Windows Toast 通知必须）───
Write-Host "==> Registering Toast AppUserModelId ..."
$RegPath = "HKCU:\SOFTWARE\Classes\AppUserModelId\$AppId"
if (-not (Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
Set-ItemProperty -Path $RegPath -Name "DisplayName" -Value $AppId
Write-Host "    Registered: $AppId"

# ─── 配置 Claude Code hooks ───
Write-Host "==> Configuring Claude Code hooks ..."

$SettingsDir = Split-Path $SettingsFile
if (-not (Test-Path $SettingsDir)) { New-Item -ItemType Directory -Force -Path $SettingsDir | Out-Null }
if (-not (Test-Path $SettingsFile)) { '{}' | Set-Content $SettingsFile -Encoding UTF8 }

$HookScript = Join-Path $InstallDir "claudecode-notification.ps1"

# Node.js 在安装了 Claude Code 的系统上一定存在
# 写入临时 JS 文件再执行，避免 node -e 的引号转义问题
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

Write-Host ""
Write-Host "==> Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Hooks registered for: UserPromptSubmit, Stop, Notification"
Write-Host "Install dir: $InstallDir"
Write-Host ""
Write-Host "On first notification, Windows may ask for notification permission." -ForegroundColor Yellow
Write-Host "If notifications don't appear: Settings → System → Notifications → ClaudeCodeNotification → On"
