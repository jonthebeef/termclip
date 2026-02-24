import AppKit
import Foundation

@MainActor
final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let config: ClipFixConfig
    private let logger: ClipFixLogger
    private let onClean: (@MainActor (String) -> Void)?

    init(config: ClipFixConfig, logger: ClipFixLogger, onClean: (@MainActor (String) -> Void)? = nil) {
        self.config = config
        self.logger = logger
        self.onClean = onClean
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkClipboard()
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let text = pasteboard.string(forType: .string) else { return }
        guard isTerminalFrontmost() else { return }

        let cleaned = ClipFixCleaner.clean(text)
        guard cleaned != text else { return }
        let linesBefore = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        let linesAfter = cleaned.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count

        pasteboard.clearContents()
        pasteboard.setString(cleaned, forType: .string)
        lastChangeCount = pasteboard.changeCount // Don't re-trigger on our own write

        try? logger.log(
            app: frontmostAppName(),
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

    private func frontmostAppName() -> String {
        return NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
    }
}
