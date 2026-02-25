import AppKit
import Foundation

@MainActor
final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let config: TermclipConfig
    private let logger: TermclipLogger
    private let onClean: (@MainActor (String) -> Void)?

    // Track the last terminal app that was frontmost, so we can still
    // clean clipboard contents even if the user switches apps before
    // the timer fires (the common case: copy in terminal, Cmd+Tab, paste)
    private var lastTerminalBundleID: String?
    private var lastTerminalName: String?
    private var observer: NSObjectProtocol?

    init(config: TermclipConfig, logger: TermclipLogger, onClean: (@MainActor (String) -> Void)? = nil) {
        self.config = config
        self.logger = logger
        self.onClean = onClean
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        // Track frontmost app changes so we know which app was active when a copy happened
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let app = NSWorkspace.shared.frontmostApplication {
                    let bundleID = app.bundleIdentifier ?? ""
                    if self.config.terminalBundleIDs.contains(bundleID) {
                        self.lastTerminalBundleID = bundleID
                        self.lastTerminalName = app.localizedName
                    }
                }
            }
        }

        // Seed with current frontmost app
        if let app = NSWorkspace.shared.frontmostApplication {
            let bundleID = app.bundleIdentifier ?? ""
            if config.terminalBundleIDs.contains(bundleID) {
                lastTerminalBundleID = bundleID
                lastTerminalName = app.localizedName
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkClipboard()
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let bundleID = app.bundleIdentifier ?? ""
        if config.terminalBundleIDs.contains(bundleID) {
            lastTerminalBundleID = bundleID
            lastTerminalName = app.localizedName
        }
    }

    private func checkClipboard() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let text = pasteboard.string(forType: .string) else { return }

        // Check if a terminal is currently frontmost OR was recently frontmost
        // (handles the common case: copy in terminal, quickly Cmd+Tab to paste)
        let isTerminal = isTerminalFrontmost()
        guard isTerminal || lastTerminalBundleID != nil else { return }

        let appName: String
        if isTerminal {
            appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        } else {
            appName = lastTerminalName ?? "Unknown"
            // Clear the last terminal — we've used it for one clipboard event
            lastTerminalBundleID = nil
            lastTerminalName = nil
        }

        let cleaned = TermclipCleaner.clean(text)
        guard cleaned != text else { return }
        let linesBefore = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        let linesAfter = cleaned.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count

        pasteboard.clearContents()
        pasteboard.setString(cleaned, forType: .string)
        lastChangeCount = pasteboard.changeCount // Don't re-trigger on our own write

        try? logger.log(
            app: appName,
            original: text,
            cleaned: cleaned,
            linesBefore: linesBefore,
            linesAfter: linesAfter
        )
        onClean?(cleaned)
    }

    private func isTerminalFrontmost() -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return config.terminalBundleIDs.contains(bundleID)
    }
}
