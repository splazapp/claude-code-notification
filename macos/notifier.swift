import AppKit
import UserNotifications

// MARK: - CLI Argument Parsing

var titleText = "Claude Code"
var subtitleText = ""
var activateBundleID: String?
var activateWindowPos: (Int, Int)?

var args = CommandLine.arguments.dropFirst()
while let arg = args.popFirst() {
    switch arg {
    case "--title":      titleText = args.popFirst() ?? titleText
    case "--subtitle":   subtitleText = args.popFirst() ?? subtitleText
    case "--activate":   activateBundleID = args.popFirst()
    case "--window-pos":
        if let posStr = args.popFirst() {
            let parts = posStr.split(separator: ",")
            if parts.count == 2, let x = Int(parts[0]), let y = Int(parts[1]) {
                activateWindowPos = (x, y)
            }
        }
    default: break
    }
}

// MARK: - App Delegate

class NotifierDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let bundleID = activateBundleID
    let windowPos = activateWindowPos
    var timeoutTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("ClaudeCodeNotification: authorization error: \(error)")
            }
            if !granted {
                NSLog("ClaudeCodeNotification: notification permission not granted, attempting anyway")
            }
            // Always try to send — sometimes works even without explicit grant
            DispatchQueue.main.async {
                self.sendNotification(center: center)
            }
        }

        // 5 min timeout to prevent zombie process
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { _ in
            NSApplication.shared.terminate(nil)
        }
    }

    func sendNotification(center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = titleText
        content.body = subtitleText
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                NSLog("ClaudeCodeNotification: failed to send notification: \(error)")
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            }
            // Keep running to receive click callback
        }
    }

    // Called when notification is clicked
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        activateTargetWindow()
        completionHandler()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }

    private func activateTargetWindow() {
        // Strategy 1: AXRaise window by position (precise window targeting)
        if let bid = bundleID, let pos = windowPos {
            if activateByPosition(bundleID: bid, x: pos.0, y: pos.1) {
                return
            }
        }
        // Strategy 2: Bundle ID activation (app-level fallback)
        if let bid = bundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config)
        }
    }

    private func activateByPosition(bundleID: String, x: Int, y: Int) -> Bool {
        // Find the app by bundle ID
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleID).first else { return false }

        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        // Get all windows
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return false
        }

        // Find window matching the captured position
        for window in windows {
            var posRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success else {
                continue
            }
            var point = CGPoint.zero
            AXValueGetValue(posRef as! AXValue, .cgPoint, &point)

            if Int(point.x) == x && Int(point.y) == y {
                // Raise this specific window and activate the app
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                app.activate()
                return true
            }
        }

        // Position didn't match any window — activate app anyway
        app.activate()
        return true
    }

    // Show notification even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No Dock icon
let delegate = NotifierDelegate()
app.delegate = delegate
app.run()
