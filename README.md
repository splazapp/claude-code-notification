# ClaudeCodeNotification

> **Stop babysitting Claude Code.** Get notified when it's done, click to jump back.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue) ![Windows](https://img.shields.io/badge/Windows-10%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![CSharp](https://img.shields.io/badge/C%23-.NET%208-purple) ![License](https://img.shields.io/badge/license-MIT-green)

## The Problem

Claude Code tasks often take minutes — sometimes much longer. While it's working, you switch to a browser, check docs, grab coffee... then find yourself constantly flipping back to check: *"Is it done yet?"*

There's no built-in way to know when Claude Code finishes. You either:
- **Stare at the terminal** and waste time waiting
- **Context-switch away** and forget to come back, losing momentum
- **Keep checking back** every 30 seconds like watching a pot boil

## The Solution

**ClaudeCodeNotification** sends a native notification the moment Claude Code completes a task. One click on the notification takes you straight back to the exact terminal or editor window — iTerm2, VS Code, Cursor, Windows Terminal, or whatever you launched it from.

No more tab-watching. Fire off a task, go do something else, and let the notification bring you back.

## Features

- **Native notifications** — macOS: `UserNotifications` framework; Windows: WinRT Toast Notifications
- **Click to return** — tap a notification to activate the originating app (iTerm2, VS Code, Cursor, Terminal, Warp, Windows Terminal)
- **Smart source detection** — macOS: `__CFBundleIdentifier` / `TERM_PROGRAM`; Windows: HWND-based precise window targeting
- **Prompt summary** — notification body shows a truncated preview of your prompt + elapsed time
- **Three hook events** — `UserPromptSubmit` (start timer), `Stop` (send result notification), `Notification` (permission/action alerts)
- **Minimal dependencies** — macOS: pure Bash + Swift; Windows: PowerShell + C# (.NET 8, self-contained exe)
- **No Dock icon / console window** — runs invisibly in the background

## How It Works

```
┌─────────────┐    hook JSON     ┌───────────────────────────┐    open -n    ┌───────────────────────────┐
│ Claude Code  │ ──────────────> │ claudecode-notification.sh │ ──────────> │ ClaudeCodeNotification.app │
│   (CLI)      │  stdin          │      (Bash router)         │             │    (Swift notifier)        │
└─────────────┘                  └───────────────────────────┘             └────────────┬──────────────┘
                                                                                        │ click
                                                                                        ▼
                                                                               NSWorkspace.shared
                                                                               .openApplication(bundleID)
                                                                                        │
                                                                                        ▼
                                                                               ┌─────────────────┐
                                                                               │ iTerm2 / VSCode  │
                                                                               │ Cursor / Terminal│
                                                                               └─────────────────┘
```

1. **`claudecode-notification.sh`** — registered as a Claude Code hook, receives JSON via stdin, tracks session state in `/tmp/claudecode-notification/`
2. **`ClaudeCodeNotification.app`** — a minimal `.app` bundle wrapping a Swift binary that sends a `UNNotificationRequest` and listens for click callbacks
3. On click, the app activates the originating terminal/editor via `NSWorkspace` using the detected bundle ID

## Installation

> **Platform support:** macOS instructions below. Jump to [Windows Installation](#windows-installation) for Windows.

### Option A: Homebrew (Recommended)

```bash
brew install splazapp/tap/claudecode-notification
claudecode-notification-setup
```

Builds from source, installs the app, then `claudecode-notification-setup` registers the Claude Code hooks.

### Option B: One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/splazapp/claude-code-notification/main/macos/install-remote.sh | bash
```

This downloads the latest release, installs the app, and configures Claude Code hooks — all in one command.

<details>
<summary>Review the script before running</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/splazapp/claude-code-notification/main/macos/install-remote.sh | less
# Then run it if you're satisfied:
curl -fsSL https://raw.githubusercontent.com/splazapp/claude-code-notification/main/macos/install-remote.sh | bash
```
</details>

To install a specific version:

```bash
VERSION=v2.0 curl -fsSL https://raw.githubusercontent.com/splazapp/claude-code-notification/main/macos/install-remote.sh | bash
```

### Option C: Clone + Install

1. Download `ClaudeCodeNotification.zip` from [Releases](https://github.com/splazapp/claude-code-notification/releases)
2. Clone, extract, and run the installer:

```bash
git clone https://github.com/splazapp/claude-code-notification.git
cd claude-code-notification/macos
# Place the downloaded ClaudeCodeNotification.app here or in dist/
bash install.sh
```

### Option D: Build from Source

Requires Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/splazapp/claude-code-notification.git
cd claude-code-notification/macos
bash install.sh   # auto-detects no .app → builds from source → installs
```

The installer will:
- Compile a universal binary (arm64 + x86_64)
- Build the `.app` bundle
- Copy files to `~/.claude/claudecode-notification/`
- Register hooks in `~/.claude/settings.json`

### Grant Notification Permission

On first run, macOS will prompt you to allow notifications for **ClaudeCodeNotification**. Click **Allow**.

## Uninstall (macOS)

```bash
git clone https://github.com/splazapp/claude-code-notification.git
cd claude-code-notification/macos
bash uninstall.sh
```

This removes the install directory and cleans up the Claude Code hooks. You'll be asked to confirm before anything is deleted.

To also remove the notification permission: **System Settings → Notifications → ClaudeCodeNotification → Remove**

---

## Windows Installation

> **Requirements:** Windows 10 version 1809 (build 17763) or later, PowerShell 5.1+, Node.js (included with Claude Code)

### Step 1: Clone the repository

```powershell
git clone https://github.com/splazapp/claude-code-notification.git
cd claude-code-notification\windows
```

### Step 2: Install (build from source)

```powershell
.\install.ps1
```

The installer will:
- Build `claudecode-notification.exe` from C# source (requires [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0))
- Copy files to `%APPDATA%\claudecode-notification\`
- Register the Toast AUMID in the registry
- Configure hooks in `%USERPROFILE%\.claude\settings.json`

### Step 2 (alternative): Build separately, then install

```powershell
# Build first (requires .NET 8 SDK)
.\build.ps1

# Then install (no SDK required at install time)
.\install.ps1
```

### Step 3: Enable notifications

On first notification, Windows may prompt to allow notifications. If none appear:

**Settings → System → Notifications → ClaudeCodeNotification → Turn on**

### Uninstall (Windows)

```powershell
cd claude-code-notification\windows
.\uninstall.ps1
```

Removes the install directory, registry AUMID, and Claude Code hooks.

## Supported Terminals & Editors (Windows)

| App | Detection Method |
|-----|-----------------|
| Windows Terminal | Process name `WindowsTerminal` → `MainWindowHandle` |
| VS Code | Process name `Code` → `MainWindowHandle` |
| Cursor | Process name `cursor` → `MainWindowHandle` |
| PowerShell 7 | Process name `pwsh` → `MainWindowHandle` |
| Windows PowerShell | Process name `powershell` → `MainWindowHandle` |
| Command Prompt | Process name `cmd` → `MainWindowHandle` |
| Alacritty / WezTerm | Process name matching → `MainWindowHandle` |

Window identification uses stable HWND values (not titles), so it works correctly even when the window title changes during task execution.

## Developer Guide

### Build only (without installing)

```bash
cd macos
bash build.sh                                    # ad-hoc signed
bash build.sh --sign "Developer ID Application: Your Name (TEAMID)"  # Developer ID
bash build.sh --sign "Developer ID ..." --notarize                    # + notarization
```

Output goes to `macos/dist/`:
- `macos/dist/ClaudeCodeNotification.app`
- `macos/dist/ClaudeCodeNotification.zip`

## Supported Terminals & Editors

| App | Detection Method |
|-----|-----------------|
| iTerm2 | `TERM_PROGRAM=iTerm.app` |
| VS Code | `TERM_PROGRAM=vscode` |
| Cursor | `TERM_PROGRAM=Cursor` |
| Apple Terminal | `TERM_PROGRAM=Apple_Terminal` |
| Warp | `TERM_PROGRAM=WarpTerminal` |

Other apps are supported if they set the `__CFBundleIdentifier` environment variable.

## Project Structure

```
claude-code-notification/
├── macos/
│   ├── claudecode-notification.sh   # Bash hook handler — routes events, tracks state
│   ├── notifier.swift               # Swift notification sender with click callback
│   ├── build.sh                     # Developer build script — universal binary + .app
│   ├── install.sh                   # Local install script
│   ├── install-remote.sh            # Remote one-line installer — curl | bash
│   ├── uninstall.sh                 # Uninstall script
│   ├── AppIcon.png                  # App icon for notifications
│   └── dist/                        # Build output (gitignored)
│       ├── ClaudeCodeNotification.app/
│       └── ClaudeCodeNotification.zip
└── windows/
    ├── claudecode-notification.ps1  # PowerShell hook handler
    ├── Notifier.cs                  # C# Toast notification sender with HWND focus
    ├── Notifier.csproj              # .NET 8 project file
    ├── build.ps1                    # Build script (dotnet publish → single exe)
    ├── install.ps1                  # Install script
    ├── uninstall.ps1                # Uninstall script
    └── dist/                        # Build output (gitignored)
        └── claudecode-notification.exe
```

## Requirements

### macOS
- macOS 13+ (Ventura or later)
- Xcode Command Line Tools (for building from source)
- Claude Code CLI

### Windows
- Windows 10 version 1809 (build 17763) or later
- PowerShell 5.1+ (pre-installed on Windows 10)
- Node.js (included with Claude Code)
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) (only needed to build from source)

## License

MIT

---

# ClaudeCodeNotification 中文说明

> **别再盯着 Claude Code 等它跑完了。** 任务完成自动通知，点一下跳回去。支持 macOS 和 Windows。

## 解决什么问题

Claude Code 的任务经常要跑几分钟甚至更久。等它执行的时候，你切去看文档、刷网页、倒杯水……然后就开始反复切回来看：*"跑完了没？"*

Claude Code 没有内置的完成通知机制。你只能：
- **盯着终端干等** — 浪费时间
- **切走做别的事** — 然后忘了回来，打断工作节奏
- **每隔 30 秒切回来看一眼** — 像盯盘一样

## 解决方案

**ClaudeCodeNotification** 在 Claude Code 完成任务的瞬间发送原生系统通知。点击通知一键跳回到你启动它的那个窗口 — 无论是 iTerm2、VS Code、Cursor、Windows Terminal 还是其他终端。

不用再盯盘了。发出任务，去做别的事，让通知把你拉回来。

## 功能特性

- **原生系统通知** — macOS：`UserNotifications` 框架；Windows：WinRT Toast 通知
- **点击跳回** — 点击通知自动激活来源应用（iTerm2、VS Code、Cursor、Terminal、Warp、Windows Terminal）
- **精准窗口定位** — macOS：窗口坐标 + AX API；Windows：HWND 句柄（稳定可靠，不受标题变化影响）
- **Prompt 摘要** — 通知正文显示你的提问摘要（前 40 字符）+ 耗时
- **三个 Hook 事件** — `UserPromptSubmit`（开始计时）、`Stop`（发送结果通知）、`Notification`（权限/操作提醒）
- **最小依赖** — macOS：纯 Bash + Swift；Windows：PowerShell + C#（.NET 8 单文件 exe，无需用户安装运行时）
- **静默运行** — 后台运行，无 Dock 图标、无控制台窗口

## 安装

### 方式 A：Homebrew 安装（推荐）

```bash
brew install splazapp/tap/claudecode-notification
claudecode-notification-setup
```

从源码编译安装，然后运行 `claudecode-notification-setup` 注册 Claude Code hooks。

### 方式 B：一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/splazapp/claude-code-notification/main/macos/install-remote.sh | bash
```

自动下载最新版本、安装应用、配置 Claude Code hooks，一行搞定。

<details>
<summary>运行前先审查脚本</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/splazapp/claude-code-notification/main/macos/install-remote.sh | less
# 确认没问题后再执行：
curl -fsSL https://raw.githubusercontent.com/splazapp/claude-code-notification/main/macos/install-remote.sh | bash
```
</details>

指定版本安装：

```bash
VERSION=v2.0 curl -fsSL https://raw.githubusercontent.com/splazapp/claude-code-notification/main/macos/install-remote.sh | bash
```

### 方式 C：Clone + 安装

1. 从 [Releases](https://github.com/splazapp/claude-code-notification/releases) 下载 `ClaudeCodeNotification.zip`
2. Clone 仓库，解压，运行安装脚本：

```bash
git clone https://github.com/splazapp/claude-code-notification.git
cd claude-code-notification/macos
# 将下载的 ClaudeCodeNotification.app 放入当前目录或 dist/
bash install.sh
```

### 方式 D：从源码编译

需要 Xcode 命令行工具（`xcode-select --install`）。

```bash
git clone https://github.com/splazapp/claude-code-notification.git
cd claude-code-notification/macos
bash install.sh   # 自动检测无 .app → 从源码编译 → 安装
```

安装脚本会自动：
- 编译 Universal Binary（arm64 + x86_64）
- 构建 `.app` Bundle
- 复制文件到 `~/.claude/claudecode-notification/`
- 注册 Hooks 到 `~/.claude/settings.json`

### 授予通知权限

首次运行时 macOS 会弹出通知权限请求，点击**允许**即可。

## 卸载（macOS）

```bash
git clone https://github.com/splazapp/claude-code-notification.git
cd claude-code-notification/macos
bash uninstall.sh
```

会删除安装目录并清理 Claude Code hooks，执行前会要求确认。

若要同时移除通知权限：**系统设置 → 通知 → ClaudeCodeNotification → 移除**

---

## Windows 安装

> **系统要求：** Windows 10 1809（build 17763）及以上，PowerShell 5.1+，Node.js（Claude Code 已包含）

### 第一步：Clone 仓库

```powershell
git clone https://github.com/splazapp/claude-code-notification.git
cd claude-code-notification\windows
```

### 第二步：安装

```powershell
.\install.ps1
```

安装脚本会自动：
- 从 C# 源码编译 `claudecode-notification.exe`（需要 [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)）
- 复制文件到 `%APPDATA%\claudecode-notification\`
- 注册 Toast AUMID 到注册表
- 配置 `%USERPROFILE%\.claude\settings.json` 中的 hooks

### 第二步（进阶）：先构建再安装

```powershell
# 先构建（需要 .NET 8 SDK）
.\build.ps1

# 再安装（安装时不需要 SDK）
.\install.ps1
```

### 第三步：允许通知

首次收到通知时 Windows 可能弹出权限请求。若通知未出现：

**设置 → 系统 → 通知 → ClaudeCodeNotification → 打开**

## 卸载（Windows）

```powershell
cd claude-code-notification\windows
.\uninstall.ps1
```

会删除安装目录、注册表项和 Claude Code hooks，执行前会要求确认。

## 开发者说明

### 仅构建（不安装）

```bash
cd macos
bash build.sh                                    # ad-hoc 签名
bash build.sh --sign "Developer ID Application: 名称 (TEAMID)"  # Developer ID 签名
bash build.sh --sign "Developer ID ..." --notarize               # + 公证
```

产物输出到 `macos/dist/` 目录。

## 系统要求

**macOS：**
- macOS 13+（Ventura 或更高版本）
- Xcode 命令行工具（从源码编译时需要）
- Claude Code CLI

**Windows：**
- Windows 10 1809（build 17763）及以上
- PowerShell 5.1+（Windows 10 内置）
- Node.js（Claude Code 已包含）
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)（仅从源码编译时需要）
