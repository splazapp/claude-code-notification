# ClaudeCodeNotification

macOS desktop notifications for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with **click-to-return** — tap the notification to jump back to the exact terminal or editor where you started.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Native macOS notifications** — built with `UserNotifications` framework, not `osascript` hacks
- **Click to return** — tap a notification to activate the originating app (iTerm2, VS Code, Cursor, Terminal, Warp)
- **Smart source detection** — automatically identifies which app launched Claude Code via `__CFBundleIdentifier` and `TERM_PROGRAM`
- **Prompt summary** — notification body shows a truncated preview of your prompt + elapsed time
- **Three hook events** — `UserPromptSubmit` (start timer), `Stop` (send result notification), `Notification` (permission/action alerts)
- **Zero dependencies** — pure Bash + Swift, uses only macOS built-in tools
- **No Dock icon** — runs as an `LSUIElement` accessory app, invisible in Dock and Cmd+Tab

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

### Option A: Download Release (Recommended)

1. Download `ClaudeCodeNotification.zip` from [Releases](https://github.com/splazapp/claude-code-notification/releases)
2. Extract and place `ClaudeCodeNotification.app` in the repo directory
3. Run the installer:

```bash
git clone https://github.com/splazapp/claude-code-notification.git
cd claude-code-notification
# Place the downloaded ClaudeCodeNotification.app here or in dist/
bash install.sh
```

### Option B: Build from Source

Requires Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/splazapp/claude-code-notification.git
cd claude-code-notification
bash install.sh   # auto-detects no .app → builds from source → installs
```

The installer will:
- Compile a universal binary (arm64 + x86_64)
- Build the `.app` bundle
- Copy files to `~/.claude/claudecode-notification/`
- Register hooks in `~/.claude/settings.json`

### Grant Notification Permission

On first run, macOS will prompt you to allow notifications for **ClaudeCodeNotification**. Click **Allow**.

## Developer Guide

### Build only (without installing)

```bash
bash build.sh                                    # ad-hoc signed
bash build.sh --sign "Developer ID Application: Your Name (TEAMID)"  # Developer ID
bash build.sh --sign "Developer ID ..." --notarize                    # + notarization
```

Output goes to `dist/`:
- `dist/ClaudeCodeNotification.app`
- `dist/ClaudeCodeNotification.zip`

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
├── claudecode-notification.sh   # Bash hook handler — routes events, tracks state
├── notifier.swift               # Swift notification sender with click callback
├── build.sh                     # Developer build script — universal binary + .app
├── install.sh                   # User install script — build (if needed) + deploy + hook config
├── AppIcon.png                  # App icon for notifications
├── .gitignore                   # Ignores dist/ and *.app
└── dist/                        # Build output (gitignored)
    ├── ClaudeCodeNotification.app/
    └── ClaudeCodeNotification.zip
```

## Requirements

- macOS 13+ (Ventura or later)
- Xcode Command Line Tools (for building from source)
- Claude Code CLI

## License

MIT

---

# ClaudeCodeNotification 中文说明

为 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 提供 macOS 原生桌面通知，支持**点击跳回** — 点击通知自动切换回你启动 Claude Code 的终端或编辑器窗口。

## 功能特性

- **原生 macOS 通知** — 基于 `UserNotifications` 框架，非 `osascript` 方案
- **点击跳回** — 点击通知自动激活来源应用（iTerm2、VS Code、Cursor、Terminal、Warp）
- **智能来源检测** — 通过 `__CFBundleIdentifier` 和 `TERM_PROGRAM` 自动识别启动 Claude Code 的应用
- **Prompt 摘要** — 通知正文显示你的提问摘要（前 40 字符）+ 耗时
- **三个 Hook 事件** — `UserPromptSubmit`（开始计时）、`Stop`（发送结果通知）、`Notification`（权限/操作提醒）
- **零依赖** — 纯 Bash + Swift，仅使用 macOS 自带工具
- **无 Dock 图标** — 以 `LSUIElement` 辅助应用运行，不出现在 Dock 和 Cmd+Tab 中

## 安装

### 方式 A：下载预编译版（推荐）

1. 从 [Releases](https://github.com/splazapp/claude-code-notification/releases) 下载 `ClaudeCodeNotification.zip`
2. 解压后将 `ClaudeCodeNotification.app` 放入仓库目录
3. 运行安装脚本：

```bash
git clone https://github.com/splazapp/claude-code-notification.git
cd claude-code-notification
bash install.sh
```

### 方式 B：从源码编译

需要 Xcode 命令行工具（`xcode-select --install`）。

```bash
git clone https://github.com/splazapp/claude-code-notification.git
cd claude-code-notification
bash install.sh   # 自动检测无 .app → 从源码编译 → 安装
```

安装脚本会自动：
- 编译 Universal Binary（arm64 + x86_64）
- 构建 `.app` Bundle
- 复制文件到 `~/.claude/claudecode-notification/`
- 注册 Hooks 到 `~/.claude/settings.json`

### 授予通知权限

首次运行时 macOS 会弹出通知权限请求，点击**允许**即可。

## 开发者说明

### 仅构建（不安装）

```bash
bash build.sh                                    # ad-hoc 签名
bash build.sh --sign "Developer ID Application: 名称 (TEAMID)"  # Developer ID 签名
bash build.sh --sign "Developer ID ..." --notarize               # + 公证
```

产物输出到 `dist/` 目录。

## 系统要求

- macOS 13+（Ventura 或更高版本）
- Xcode 命令行工具（从源码编译时需要）
- Claude Code CLI
