// ClaudeCodeNotification - Windows Toast Notifier
// Sends a native Windows Toast notification and focuses the originating terminal on click.
//
// Usage: claudecode-notification.exe --title <title> --subtitle <subtitle> [--hwnd <hwnd>]
//
// Requirements:
//   - AUMID "ClaudeCodeNotification" registered in registry (done by install.ps1)
//   - Windows 10 1809+ / Windows 11

using System;
using System.Runtime.InteropServices;
using System.Threading;
using Windows.UI.Notifications;
using Windows.Data.Xml.Dom;

[assembly: System.Runtime.Versioning.SupportedOSPlatform("windows10.0.17763.0")]

class Program
{
    // ─── Win32 P/Invoke ───
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] static extern bool AllowSetForegroundWindow(int dwProcessId);
    const int SW_RESTORE = 9;
    const string AppId = "ClaudeCodeNotification";

    [STAThread]
    static int Main(string[] args)
    {
        string title    = "Claude Code";
        string subtitle = "";
        IntPtr hwnd     = IntPtr.Zero;

        // ─── 解析命令行参数 ───
        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--title":
                    if (i + 1 < args.Length) title = args[++i];
                    break;
                case "--subtitle":
                    if (i + 1 < args.Length) subtitle = args[++i];
                    break;
                case "--hwnd":
                    if (i + 1 < args.Length && long.TryParse(args[++i], out long h))
                        hwnd = new IntPtr(h);
                    break;
            }
        }

        var targetHwnd = hwnd;
        var done = new ManualResetEventSlim(false);

        // ─── 构建 Toast XML ───
        string xml = $"""
            <toast>
                <visual>
                    <binding template="ToastGeneric">
                        <text>{EscapeXml(title)}</text>
                        <text>{EscapeXml(subtitle)}</text>
                    </binding>
                </visual>
                <audio src="ms-winsoundevent:Notification.Default"/>
            </toast>
            """;

        var xmlDoc = new XmlDocument();
        xmlDoc.LoadXml(xml);

        var toast = new ToastNotification(xmlDoc);

        // ─── 点击通知 → 跳回终端窗口 ───
        toast.Activated += (s, e) =>
        {
            if (targetHwnd != IntPtr.Zero && IsWindow(targetHwnd))
            {
                // 允许前台切换（绕过 Windows 前台限制）
                AllowSetForegroundWindow(-1); // ASFW_ANY
                ShowWindow(targetHwnd, SW_RESTORE);
                SetForegroundWindow(targetHwnd);
            }
            done.Set();
        };

        toast.Dismissed += (s, e) => done.Set();
        toast.Failed    += (s, e) => done.Set();

        // ─── 显示通知 ───
        var notifier = ToastNotificationManager.CreateToastNotifier(AppId);
        notifier.Show(toast);

        // 等待最多 5 分钟（防止僵尸进程）
        done.Wait(TimeSpan.FromMinutes(5));
        return 0;
    }

    // ─── XML 特殊字符转义 ───
    static string EscapeXml(string s) =>
        s.Replace("&",  "&amp;")
         .Replace("<",  "&lt;")
         .Replace(">",  "&gt;")
         .Replace("\"", "&quot;")
         .Replace("'",  "&apos;");
}
