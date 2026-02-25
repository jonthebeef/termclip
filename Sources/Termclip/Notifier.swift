import Foundation
import UserNotifications

final class TermclipNotifier: Sendable {
    /// Returns true if UNUserNotificationCenter is safe to use (requires a bundled app context).
    private static var isAvailable: Bool {
        return Bundle.main.bundleIdentifier != nil
    }

    static func requestPermission() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    static func send(cleanedText: String) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "Termclip"
        content.body = String(cleanedText.prefix(60)) + (cleanedText.count > 60 ? "..." : "")
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
