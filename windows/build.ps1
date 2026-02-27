# ClaudeCodeNotification - Windows Build Script
# 构建单文件自包含 exe（用户无需安装 .NET）
#
# Usage: .\build.ps1
# Output: windows\dist\claudecode-notification.exe

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== ClaudeCodeNotification Windows Build ===" -ForegroundColor Cyan
Write-Host ""

# ─── 检查 .NET SDK ───
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host "Error: .NET SDK not found." -ForegroundColor Red
    Write-Host "Install from: https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Yellow
    exit 1
}

$dotnetVersion = (dotnet --version)
Write-Host "dotnet version: $dotnetVersion"
Write-Host ""

# ─── 构建 ───
$projFile = Join-Path $ScriptDir "Notifier.csproj"
$outDir   = Join-Path $ScriptDir "dist"

Write-Host "==> Building claudecode-notification.exe ..."

Push-Location $ScriptDir
try {
    dotnet publish $projFile `
        -c Release `
        -r win-x64 `
        --self-contained true `
        -p:PublishSingleFile=true `
        -p:IncludeNativeLibrariesForSelfExtract=true `
        -o $outDir `
        --nologo
} finally {
    Pop-Location
}

# ─── 验证输出 ───
$exePath = Join-Path $outDir "claudecode-notification.exe"
if (Test-Path $exePath) {
    $sizeMB = [math]::Round((Get-Item $exePath).Length / 1MB, 1)
    Write-Host ""
    Write-Host "==> Build complete!" -ForegroundColor Green
    Write-Host "    Output : $exePath"
    Write-Host "    Size   : ${sizeMB} MB"
} else {
    Write-Host "Error: Build failed - claudecode-notification.exe not found." -ForegroundColor Red
    exit 1
}
