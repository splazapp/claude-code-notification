# ClaudeCodeNotification - Windows PowerShell hook script
# 点击通知自动跳回启动 Claude Code 的终端窗口
#
# Usage: powershell.exe -ExecutionPolicy Bypass -NonInteractive -File script.ps1 <Event>
# Events: UserPromptSubmit | Stop | Notification
# JSON payload is read from stdin.

param([string]$Event)

$StateDir = "$env:TEMP\claudecode-notification"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$NotifierExe = Join-Path $ScriptDir "claudecode-notification.exe"

# ─── JSON 解析 ───
function Get-JsonField {
    param([string]$Json, [string]$Key)
    try {
        $obj = $Json | ConvertFrom-Json
        return $obj.$Key
    } catch {
        return $null
    }
}

# ─── 沿进程树查找终端窗口句柄（HWND）───
# 从当前 PowerShell 进程向上遍历父进程，找到终端宿主进程
function Get-TerminalHwnd {
    $terminalNames = @('WindowsTerminal', 'Code', 'cursor', 'pwsh', 'powershell', 'cmd', 'alacritty', 'wezterm', 'mintty')
    $pid = $PID
    $visited = @{}

    while ($pid -gt 1) {
        if ($visited[$pid]) { break }
        $visited[$pid] = $true

        try {
            $proc = [System.Diagnostics.Process]::GetProcessById($pid)
            if ($proc.ProcessName -in $terminalNames -and $proc.MainWindowHandle -ne [IntPtr]::Zero) {
                return $proc.MainWindowHandle.ToInt64()
            }
            # 获取父进程 PID（通过 WMI）
            $wmiProc = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $pid" -Property ParentProcessId -ErrorAction SilentlyContinue
            if ($null -eq $wmiProc) { break }
            $pid = [int]$wmiProc.ParentProcessId
        } catch {
            break
        }
    }

    # 回退：获取当前前台窗口
    try {
        Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public class WinHelper {
    [DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow();
}
'@ -ErrorAction SilentlyContinue
        return [WinHelper]::GetForegroundWindow().ToInt64()
    } catch {
        return 0
    }
}

# ─── Unix 时间戳 ───
function Get-UnixTime {
    $epoch = [DateTime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
    return [int]([DateTime]::UtcNow - $epoch).TotalSeconds
}

# ─── 耗时格式化 ───
function Format-Duration {
    param([int]$Seconds)
    if ($Seconds -lt 60)   { return "${Seconds}s" }
    elseif ($Seconds -lt 3600) { return "$([int]($Seconds/60))m$([int]($Seconds%60))s" }
    else { return "$([int]($Seconds/3600))h$([int](($Seconds%3600)/60))m" }
}

# ─── 发送通知（调用 C# 通知器）───
function Send-Notification {
    param([string]$Title, [string]$Subtitle, [string]$Hwnd)
    if (-not (Test-Path $NotifierExe)) { return }
    $notifierArgs = @("--title", $Title, "--subtitle", $Subtitle)
    if ($Hwnd -and $Hwnd -ne "0") {
        $notifierArgs += @("--hwnd", $Hwnd)
    }
    Start-Process -FilePath $NotifierExe -ArgumentList $notifierArgs -WindowStyle Hidden
}

# ─── Hook: UserPromptSubmit ───
function Handle-UserPromptSubmit {
    $json = $InputData
    $sessionId  = Get-JsonField $json "session_id"
    $cwd        = Get-JsonField $json "cwd"
    $userPrompt = Get-JsonField $json "user_prompt"
    if (-not $sessionId) { return }

    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null

    # 记录开始时间和工作目录
    Get-UnixTime | Set-Content "$StateDir\$sessionId.start" -Encoding UTF8
    if ($cwd) { $cwd | Set-Content "$StateDir\$sessionId.cwd" -Encoding UTF8 }

    # 捕获终端窗口 HWND（用于点击通知时精准跳回）
    $hwnd = Get-TerminalHwnd
    $hwnd | Set-Content "$StateDir\$sessionId.hwnd" -Encoding UTF8

    # 保存 prompt 摘要（前 40 个字符，去换行）
    if ($userPrompt) {
        $flat = ($userPrompt -replace '[\r\n]+', ' ').Trim()
        $summary = if ($flat.Length -gt 40) { $flat.Substring(0, 40) } else { $flat }
        $summary | Set-Content "$StateDir\$sessionId.prompt" -Encoding UTF8
    }

    # 任务序号自增
    $seqFile = "$StateDir\$sessionId.seq"
    $seq = 0
    if (Test-Path $seqFile) { $seq = [int](Get-Content $seqFile -Encoding UTF8) }
    ($seq + 1) | Set-Content $seqFile -Encoding UTF8
}

# ─── Hook: Stop ───
function Handle-Stop {
    $json = $InputData
    $sessionId = Get-JsonField $json "session_id"
    if (-not $sessionId) { return }

    $startFile = "$StateDir\$sessionId.start"
    if (-not (Test-Path $startFile)) { return }

    $startTs  = [int](Get-Content $startFile -Encoding UTF8)
    $duration = Format-Duration ((Get-UnixTime) - $startTs)
    $cwd      = if (Test-Path "$StateDir\$sessionId.cwd")    { Get-Content "$StateDir\$sessionId.cwd"    -Encoding UTF8 } else { "" }
    $hwnd     = if (Test-Path "$StateDir\$sessionId.hwnd")   { Get-Content "$StateDir\$sessionId.hwnd"   -Encoding UTF8 } else { "0" }
    $summary  = if (Test-Path "$StateDir\$sessionId.prompt") { Get-Content "$StateDir\$sessionId.prompt" -Encoding UTF8 } else { "" }

    $title    = if ($cwd) { Split-Path -Leaf $cwd } else { "Claude" }
    $subtitle = if ($summary) { "${summary}... · ${duration}" } else { "done · ${duration}" }

    Send-Notification $title $subtitle $hwnd

    Remove-Item -Force "$StateDir\$sessionId.start"  -ErrorAction SilentlyContinue
    Remove-Item -Force "$StateDir\$sessionId.prompt" -ErrorAction SilentlyContinue
    Remove-Item -Force "$StateDir\$sessionId.hwnd"   -ErrorAction SilentlyContinue
}

# ─── Hook: Notification ───
function Handle-Notification {
    $json      = $InputData
    $sessionId = Get-JsonField $json "session_id"
    $message   = Get-JsonField $json "message"
    $cwd       = Get-JsonField $json "cwd"

    $hwnd = if ($sessionId -and (Test-Path "$StateDir\$sessionId.hwnd")) {
        Get-Content "$StateDir\$sessionId.hwnd" -Encoding UTF8
    } else { "0" }

    if (-not $message) { return }
    $lowerMsg = $message.ToLower()
    if ($lowerMsg -match 'waiting for.+input') { return }

    $subtitle = if     ($lowerMsg -match 'permission')           { "Permission Required" }
                elseif ($lowerMsg -match 'approval|choose an option') { "Action Required" }
                else                                              { "Notification" }

    if ($sessionId -and (Test-Path "$StateDir\$sessionId.prompt")) {
        $promptCtx = Get-Content "$StateDir\$sessionId.prompt" -Encoding UTF8
        if ($promptCtx) { $subtitle = "${promptCtx}... · ${subtitle}" }
    }

    $title = if ($cwd) { Split-Path -Leaf $cwd } else { "Claude" }
    Send-Notification $title $subtitle $hwnd
}

# ─── 主入口 ───
if (-not $Event) { Write-Output "ok"; exit 0 }

# 从 stdin 读取 JSON（Claude Code 通过管道传入）
$InputData = if ([Console]::IsInputRedirected) { [Console]::In.ReadToEnd() } else { "" }
if (-not $InputData) { exit 0 }

switch ($Event) {
    "UserPromptSubmit" { Handle-UserPromptSubmit }
    "Stop"             { Handle-Stop }
    "Notification"     { Handle-Notification }
}
