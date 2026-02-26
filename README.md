# ClaudeCode Tap

macOS desktop notifications for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with **click-to-return** — tap the notification to jump back to the exact terminal or editor where you started.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Native macOS notifications** — built with `UserNotifications` framework, not `osascript` hacks
- **Click to return** — tap a notification to activate the originating app (iTerm2, VS Code, Cursor, Terminal, Warp)
- **Smart source detection** — automatically identifies which app launched Claude Code via `__CFBundleIdentifier` and `TERM_PROGRAM`
- **Prompt summary** — notification body shows a truncated preview of your prompt + elapsed time
- **Three hook events** — `UserPromptSubmit` (start timer), `Stop` (send result notification), `Notification` (permission/action alerts)
- **Zero dependencies** — pure Bash + Swift, uses only macOS built-in tools (`plutil`, `codesign`, `swiftc`)
- **No Dock icon** — runs as an `LSUIElement` accessory app, invisible in Dock and Cmd+Tab

## How It Works

```
┌─────────────┐    hook JSON     ┌──────────────────┐    open -n    ┌──────────────────┐
│ Claude Code  │ ──────────────> │ claudecode-tap.sh │ ──────────> │ ClaudeCodeTap.app │
│   (CLI)      │  stdin          │   (Bash router)   │             │  (Swift notifier) │
└─────────────┘                  └──────────────────┘             └────────┬─────────┘
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

1. **`claudecode-tap.sh`** — registered as a Claude Code hook, receives JSON via stdin, tracks session state in `/tmp/claudecode-tap/`
2. **`ClaudeCodeTap.app`** — a minimal `.app` bundle wrapping a Swift binary that sends a `UNNotificationRequest` and listens for click callbacks
3. On click, the app activates the originating terminal/editor via `NSWorkspace` using the detected bundle ID

## Installation

### 1. Clone & build

```bash
git clone https://github.com/user/claude-code-tap.git
cd claude-code-tap
bash install.sh
```

### 2. Install to Claude Code

Copy files to Claude Code's config directory:

```bash
mkdir -p ~/.claude/claudecode-tap
cp claudecode-tap.sh notifier.swift install.sh AppIcon.png ~/.claude/claudecode-tap/
cp -r ClaudeCodeTap.app ~/.claude/claudecode-tap/
chmod +x ~/.claude/claudecode-tap/claudecode-tap.sh
```

### 3. Register hooks

Add the following to `~/.claude/settings.json` (create if it doesn't exist):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/Users/YOUR_USERNAME/.claude/claudecode-tap/claudecode-tap.sh UserPromptSubmit"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/Users/YOUR_USERNAME/.claude/claudecode-tap/claudecode-tap.sh Stop"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/Users/YOUR_USERNAME/.claude/claudecode-tap/claudecode-tap.sh Notification"
          }
        ]
      }
    ]
  }
}
```

Replace `YOUR_USERNAME` with your macOS username.

### 4. Grant notification permission

On first run, macOS will prompt you to allow notifications for **ClaudeCode Tap**. Click **Allow**.

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
claude-code-tap/
├── claudecode-tap.sh   # Bash hook handler — routes events, tracks state
├── notifier.swift      # Swift notification sender with click callback
├── install.sh          # Build script — compiles Swift, creates .app bundle
├── AppIcon.png         # App icon for notifications
└── ClaudeCodeTap.app/  # Built .app bundle (generated by install.sh)
    └── Contents/
        ├── Info.plist
        ├── MacOS/claudecode-tap
        └── Resources/AppIcon.png
```

## Requirements

- macOS 13+ (Ventura or later)
- Xcode Command Line Tools (`xcode-select --install`)
- Claude Code CLI

## License

MIT

---

# ClaudeCode Tap 中文说明

为 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 提供 macOS 原生桌面通知，支持**点击跳回** — 点击通知自动切换回你启动 Claude Code 的终端或编辑器窗口。

## 功能特性

- **原生 macOS 通知** — 基于 `UserNotifications` 框架，非 `osascript` 方案
- **点击跳回** — 点击通知自动激活来源应用（iTerm2、VS Code、Cursor、Terminal、Warp）
- **智能来源检测** — 通过 `__CFBundleIdentifier` 和 `TERM_PROGRAM` 自动识别启动 Claude Code 的应用
- **Prompt 摘要** — 通知正文显示你的提问摘要（前 40 字符）+ 耗时
- **三个 Hook 事件** — `UserPromptSubmit`（开始计时）、`Stop`（发送结果通知）、`Notification`（权限/操作提醒）
- **零依赖** — 纯 Bash + Swift，仅使用 macOS 自带工具
- **无 Dock 图标** — 以 `LSUIElement` 辅助应用运行，不出现在 Dock 和 Cmd+Tab 中

## 工作原理

1. **`claudecode-tap.sh`** — 注册为 Claude Code Hook，通过 stdin 接收 JSON，在 `/tmp/claudecode-tap/` 跟踪会话状态
2. **`ClaudeCodeTap.app`** — 最小化 `.app` Bundle，内含 Swift 二进制，发送 `UNNotificationRequest` 并监听点击回调
3. 点击通知时，通过 `NSWorkspace` 使用检测到的 Bundle ID 激活来源应用

## 安装

### 1. 克隆并编译

```bash
git clone https://github.com/user/claude-code-tap.git
cd claude-code-tap
bash install.sh
```

### 2. 安装到 Claude Code

```bash
mkdir -p ~/.claude/claudecode-tap
cp claudecode-tap.sh notifier.swift install.sh AppIcon.png ~/.claude/claudecode-tap/
cp -r ClaudeCodeTap.app ~/.claude/claudecode-tap/
chmod +x ~/.claude/claudecode-tap/claudecode-tap.sh
```

### 3. 注册 Hooks

在 `~/.claude/settings.json` 中添加（将 `YOUR_USERNAME` 替换为你的 macOS 用户名）：

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "/Users/YOUR_USERNAME/.claude/claudecode-tap/claudecode-tap.sh UserPromptSubmit" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "/Users/YOUR_USERNAME/.claude/claudecode-tap/claudecode-tap.sh Stop" }] }
    ],
    "Notification": [
      { "hooks": [{ "type": "command", "command": "/Users/YOUR_USERNAME/.claude/claudecode-tap/claudecode-tap.sh Notification" }] }
    ]
  }
}
```

### 4. 授予通知权限

首次运行时 macOS 会弹出通知权限请求，点击**允许**即可。

## 系统要求

- macOS 13+（Ventura 或更高版本）
- Xcode 命令行工具（`xcode-select --install`）
- Claude Code CLI
