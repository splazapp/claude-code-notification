import AppKit
import UserNotifications

// MARK: - CLI Argument Parsing

var titleText = "Claude Code"
var subtitleText = ""
var activateBundleID: String?

var args = CommandLine.arguments.dropFirst()
while let arg = args.popFirst() {
    switch arg {
    case "--title":    titleText = args.popFirst() ?? titleText
    case "--subtitle": subtitleText = args.popFirst() ?? subtitleText
    case "--activate": activateBundleID = args.popFirst()
    default: break
    }
}

// MARK: - App Delegate

class NotifierDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let bundleID = activateBundleID
    var timeoutTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("ClaudeCodeTap: authorization error: \(error)")
            }
            if !granted {
                NSLog("ClaudeCodeTap: notification permission not granted, attempting anyway")
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
                NSLog("ClaudeCodeTap: failed to send notification: \(error)")
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
        if let bid = bundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config)
        }
        completionHandler()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
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
