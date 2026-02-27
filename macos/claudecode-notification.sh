#!/bin/bash
# ClaudeCodeNotification - 纯 sh 精简版：智能跳转通知
# 点击通知自动跳回启动 Claude Code 的应用窗口

STATE_DIR="/tmp/claudecode-notification"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NOTIFIER_APP="$SCRIPT_DIR/ClaudeCodeNotification.app/Contents/MacOS/claudecode-notification"

# ─── JSON 解析（plutil macOS 自带）───
json_get() { echo "$INPUT" | plutil -extract "$1" raw -o - -- - 2>/dev/null; }

# ─── 捕获前台窗口位置（用于多窗口定位）───
# 窗口标题会动态变化（spinner），位置在任务执行期间保持稳定
capture_window_pos() {
    osascript -e '
tell application "System Events"
    tell (first process whose frontmost is true)
        if exists window 1 then
            set p to position of window 1
            return (item 1 of p as text) & "," & (item 2 of p as text)
        end if
    end tell
end tell' 2>/dev/null
}

# ─── 智能检测启动应用 Bundle ID ───
detect_bundle_id() {
    # Tier 1: 直接读环境变量
    if [ -n "$__CFBundleIdentifier" ]; then
        echo "$__CFBundleIdentifier"
        return
    fi
    # Tier 2: TERM_PROGRAM 映射
    case "$TERM_PROGRAM" in
        iTerm.app)      echo "com.googlecode.iterm2" ;;
        vscode)         echo "com.microsoft.VSCode" ;;
        Apple_Terminal) echo "com.apple.Terminal" ;;
        WarpTerminal)   echo "dev.warp.Warp-Stable" ;;
        Cursor)         echo "com.todesktop.230313mzl4w4u92" ;;
        *)              echo "" ;;
    esac
}

# ─── 耗时格式化 ───
format_duration() {
    local secs=$1
    if [ "$secs" -lt 60 ]; then echo "${secs}s"
    elif [ "$secs" -lt 3600 ]; then echo "$((secs/60))m$((secs%60))s"
    else echo "$((secs/3600))h$(((secs%3600)/60))m"
    fi
}

# ─── 发送通知（Swift 工具支持点击跳回）───
send_notification() {
    local title="$1" subtitle="$2" bundle_id="$3" win_pos="$4"
    local app_bundle="$SCRIPT_DIR/ClaudeCodeNotification.app"
    if [ -d "$app_bundle" ]; then
        # Must use 'open' to launch through LaunchServices for proper bundle context
        local -a notify_args=(--title "$title" --subtitle "$subtitle")
        [ -n "$bundle_id" ] && notify_args+=(--activate "$bundle_id")
        [ -n "$win_pos" ] && notify_args+=(--window-pos "$win_pos")
        open -n "$app_bundle" --args "${notify_args[@]}" 2>/dev/null &
        disown
    else
        # Fallback: osascript（无点击回调）
        osascript -e "display notification \"$subtitle\" with title \"$title\" sound name \"default\"" 2>/dev/null
    fi
}

# ─── Hook: UserPromptSubmit ───
handle_user_prompt_submit() {
    local session_id; session_id=$(json_get session_id)
    local cwd; cwd=$(json_get cwd)
    local bundle_id; bundle_id=$(detect_bundle_id)
    mkdir -p "$STATE_DIR"
    date +%s > "$STATE_DIR/${session_id}.start"
    echo "$cwd" > "$STATE_DIR/${session_id}.cwd"
    echo "$bundle_id" > "$STATE_DIR/${session_id}.app"
    # 捕获前台窗口位置（用于点击通知时定位到具体窗口）
    local win_pos; win_pos=$(capture_window_pos)
    [ -n "$win_pos" ] && echo "$win_pos" > "$STATE_DIR/${session_id}.winpos"
    # 捕获 user_prompt 摘要（截取前 40 字符，去换行）
    local prompt; prompt=$(json_get user_prompt)
    if [ -n "$prompt" ]; then
        local summary; summary=$(echo "$prompt" | tr '\n' ' ' | cut -c1-40)
        echo "$summary" > "$STATE_DIR/${session_id}.prompt"
    fi
    # 任务序号自增
    local seq_file="$STATE_DIR/${session_id}.seq"
    local seq=$(($(cat "$seq_file" 2>/dev/null || echo 0) + 1))
    echo "$seq" > "$seq_file"
}

# ─── Hook: Stop ───
handle_stop() {
    local session_id; session_id=$(json_get session_id)
    local start_file="$STATE_DIR/${session_id}.start"
    [ ! -f "$start_file" ] && return
    local start_ts; start_ts=$(cat "$start_file")
    local cwd; cwd=$(cat "$STATE_DIR/${session_id}.cwd" 2>/dev/null)
    local bundle_id; bundle_id=$(cat "$STATE_DIR/${session_id}.app" 2>/dev/null)
    local seq; seq=$(cat "$STATE_DIR/${session_id}.seq" 2>/dev/null || echo 1)
    local duration; duration=$(format_duration $(($(date +%s) - start_ts)))
    local title; title=$(basename "${cwd:-Claude}")
    local summary; summary=$(cat "$STATE_DIR/${session_id}.prompt" 2>/dev/null)
    local subtitle
    if [ -n "$summary" ]; then
        subtitle="${summary}... · ${duration}"
    else
        subtitle="done · ${duration}"
    fi
    local win_pos; win_pos=$(cat "$STATE_DIR/${session_id}.winpos" 2>/dev/null)
    send_notification "$title" "$subtitle" "$bundle_id" "$win_pos"
    rm -f "$start_file" "$STATE_DIR/${session_id}.prompt" "$STATE_DIR/${session_id}.winpos"
}

# ─── Hook: Notification ───
handle_notification() {
    local session_id; session_id=$(json_get session_id)
    local message; message=$(json_get message)
    local cwd; cwd=$(json_get cwd)
    local bundle_id; bundle_id=$(cat "$STATE_DIR/${session_id}.app" 2>/dev/null)
    [ -z "$bundle_id" ] && bundle_id=$(detect_bundle_id)
    local lower_msg; lower_msg=$(echo "$message" | tr '[:upper:]' '[:lower:]')
    case "$lower_msg" in
        *"waiting for"*"input"*) return ;;
        *"permission"*)                    local subtitle="Permission Required" ;;
        *"approval"*|*"choose an option"*) local subtitle="Action Required" ;;
        *)                                 local subtitle="Notification" ;;
    esac
    local title; title=$(basename "${cwd:-Claude}")
    local prompt_ctx; prompt_ctx=$(cat "$STATE_DIR/${session_id}.prompt" 2>/dev/null)
    [ -n "$prompt_ctx" ] && subtitle="${prompt_ctx}... · ${subtitle}"
    local win_pos; win_pos=$(cat "$STATE_DIR/${session_id}.winpos" 2>/dev/null)
    send_notification "$title" "$subtitle" "$bundle_id" "$win_pos"
}

# ─── 主入口 ───
[ $# -lt 1 ] && echo "ok" && exit 0
INPUT=$(cat)
[ -z "$INPUT" ] && exit 0
case "$1" in
    UserPromptSubmit) handle_user_prompt_submit ;;
    Stop)             handle_stop ;;
    Notification)     handle_notification ;;
esac
