# Termclip Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS daemon that monitors the clipboard and auto-cleans text copied from terminal apps using heuristics.

**Architecture:** Single Swift binary acting as both CLI and background daemon. Monitors pasteboard change count in a timer loop, checks frontmost app against known terminal bundle IDs, applies heuristic cleaning engine, writes cleaned text back. CLI subcommands control the daemon via PID file and signals.

**Tech Stack:** Swift 6.1, Swift Package Manager, AppKit (NSPasteboard, NSWorkspace), UserNotifications, Foundation (Process, FileManager, JSONEncoder/Decoder), XCTest

---

### Task 1: Swift Package Scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/Termclip/main.swift`

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Termclip",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "termclip",
            path: "Sources/Termclip"
        ),
        .testTarget(
            name: "TermclipTests",
            dependencies: ["termclip"],
            path: "Tests/TermclipTests"
        ),
    ]
)
```

**Step 2: Create minimal main.swift**

```swift
import Foundation

print("termclip v0.1.0")
```

**Step 3: Build and verify**

Run: `cd /Users/thingy/Desktop/onestring && swift build 2>&1`
Expected: Build succeeds, produces `.build/debug/termclip`

**Step 4: Run it**

Run: `.build/debug/termclip`
Expected: Prints `termclip v0.1.0`

**Step 5: Commit**

```bash
git add Package.swift Sources/
git commit -m "feat: scaffold Swift package"
```

---

### Task 2: Config Module

**Files:**
- Create: `Sources/Termclip/Config.swift`
- Create: `Tests/TermclipTests/ConfigTests.swift`

**Step 1: Write the failing tests**

```swift
import XCTest
@testable import termclip

final class ConfigTests: XCTestCase {
    let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("termclip-test-\(UUID().uuidString)")

    override func setUp() {
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
    }

    func testDefaultConfig() {
        let config = TermclipConfig.defaultConfig
        XCTAssertFalse(config.notificationsEnabled)
        XCTAssertTrue(config.terminalBundleIDs.contains("com.apple.Terminal"))
        XCTAssertTrue(config.terminalBundleIDs.contains("com.googlecode.iterm2"))
    }

    func testSaveAndLoad() throws {
        let configPath = testDir.appendingPathComponent("config.json")
        var config = TermclipConfig.defaultConfig
        config.notificationsEnabled = true
        try config.save(to: configPath)
        let loaded = try TermclipConfig.load(from: configPath)
        XCTAssertTrue(loaded.notificationsEnabled)
        XCTAssertEqual(loaded.terminalBundleIDs, config.terminalBundleIDs)
    }

    func testLoadMissingFileReturnsDefault() {
        let missing = testDir.appendingPathComponent("nonexistent.json")
        let config = (try? TermclipConfig.load(from: missing)) ?? .defaultConfig
        XCTAssertFalse(config.notificationsEnabled)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `TermclipConfig` not defined

**Step 3: Implement Config**

```swift
import Foundation

struct TermclipConfig: Codable {
    var notificationsEnabled: Bool
    var terminalBundleIDs: [String]

    static let defaultConfig = TermclipConfig(
        notificationsEnabled: false,
        terminalBundleIDs: [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "dev.warp.Warp-Stable",
            "com.microsoft.VSCode",
            "net.kovidgoyal.kitty",
            "io.alacritty",
            "com.github.wez.wezterm",
            "co.zeit.hyper",
            "dev.zed.Zed",
            "com.todesktop.230313mzl4w4u92",
        ]
    )

    static func load(from url: URL) throws -> TermclipConfig {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TermclipConfig.self, from: data)
    }

    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -20`
Expected: All 3 tests PASS

**Step 5: Commit**

```bash
git add Sources/Termclip/Config.swift Tests/
git commit -m "feat: add config module with save/load and defaults"
```

---

### Task 3: Paths Module

**Files:**
- Create: `Sources/Termclip/Paths.swift`
- Create: `Tests/TermclipTests/PathsTests.swift`

**Step 1: Write the failing tests**

```swift
import XCTest
@testable import termclip

final class PathsTests: XCTestCase {
    func testPathsPointToClipfixDir() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let expected = home.appendingPathComponent(".termclip")
        XCTAssertEqual(TermclipPaths.baseDir, expected)
        XCTAssertEqual(TermclipPaths.configFile, expected.appendingPathComponent("config.json"))
        XCTAssertEqual(TermclipPaths.pidFile, expected.appendingPathComponent("termclip.pid"))
        XCTAssertEqual(TermclipPaths.logFile, expected.appendingPathComponent("termclip.log"))
    }

    func testEnsureDirectoryCreatesDir() throws {
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("termclip-paths-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDir) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: testDir.path))
        try TermclipPaths.ensureDirectory(testDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: testDir.path))
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `TermclipPaths` not defined

**Step 3: Implement Paths**

```swift
import Foundation

enum TermclipPaths {
    static let baseDir: URL = {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".termclip")
    }()

    static let configFile = baseDir.appendingPathComponent("config.json")
    static let pidFile = baseDir.appendingPathComponent("termclip.pid")
    static let logFile = baseDir.appendingPathComponent("termclip.log")

    static let launchdPlist: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.termclip.agent.plist")
    }()

    static func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -20`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add Sources/Termclip/Paths.swift Tests/TermclipTests/PathsTests.swift
git commit -m "feat: add paths module for file locations"
```

---

### Task 4: Logger Module

**Files:**
- Create: `Sources/Termclip/Logger.swift`
- Create: `Tests/TermclipTests/LoggerTests.swift`

**Step 1: Write the failing tests**

```swift
import XCTest
@testable import termclip

final class LoggerTests: XCTestCase {
    let testLogFile = FileManager.default.temporaryDirectory.appendingPathComponent("termclip-log-test-\(UUID().uuidString).log")

    override func tearDown() {
        try? FileManager.default.removeItem(at: testLogFile)
    }

    func testLogWritesEntry() throws {
        let logger = TermclipLogger(file: testLogFile)
        try logger.log(app: "iTerm2", original: "  scp foo\n  bar", cleaned: "scp foo bar", linesBefore: 2, linesAfter: 1)
        let contents = try String(contentsOf: testLogFile, encoding: .utf8)
        XCTAssertTrue(contents.contains("iTerm2"))
        XCTAssertTrue(contents.contains("2 lines → 1"))
        XCTAssertTrue(contents.contains("scp foo bar"))
    }

    func testLogCapsAt1000Entries() throws {
        let logger = TermclipLogger(file: testLogFile, maxEntries: 10)
        for i in 0..<15 {
            try logger.log(app: "Term", original: "line \(i)", cleaned: "line \(i)", linesBefore: 1, linesAfter: 1)
        }
        let contents = try String(contentsOf: testLogFile, encoding: .utf8)
        let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 10)
        XCTAssertTrue(contents.contains("line 14"))
        XCTAssertFalse(contents.contains("line 0"))
    }

    func testRecentReturnsLastN() throws {
        let logger = TermclipLogger(file: testLogFile)
        for i in 0..<5 {
            try logger.log(app: "Term", original: "cmd \(i)", cleaned: "cmd \(i)", linesBefore: 1, linesAfter: 1)
        }
        let recent = try logger.recent(count: 3)
        XCTAssertEqual(recent.count, 3)
        XCTAssertTrue(recent.last!.contains("cmd 4"))
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `TermclipLogger` not defined

**Step 3: Implement Logger**

```swift
import Foundation

final class TermclipLogger {
    let file: URL
    let maxEntries: Int

    init(file: URL, maxEntries: Int = 1000) {
        self.file = file
        self.maxEntries = maxEntries
    }

    func log(app: String, original: String, cleaned: String, linesBefore: Int, linesAfter: Int) throws {
        let timestamp = ISO8601DateFormatter.localFormatter.string(from: Date())
        let preview = String(cleaned.prefix(60))
        let entry = "[\(timestamp)] Cleaned from \(app): \"\(preview)\" (\(linesBefore) lines → \(linesAfter))\n"

        var lines = (try? String(contentsOf: file, encoding: .utf8))?
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty } ?? []
        lines.append(entry.trimmingCharacters(in: .newlines))

        if lines.count > maxEntries {
            lines = Array(lines.suffix(maxEntries))
        }

        try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
    }

    func recent(count: Int = 20) throws -> [String] {
        let contents = try String(contentsOf: file, encoding: .utf8)
        let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return Array(lines.suffix(count))
    }
}

extension ISO8601DateFormatter {
    static let localFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -20`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add Sources/Termclip/Logger.swift Tests/TermclipTests/LoggerTests.swift
git commit -m "feat: add rolling log with cap and recent retrieval"
```

---

### Task 5: Cleaning Heuristics Engine (Core)

This is the heart of Termclip. Heaviest test coverage.

**Files:**
- Create: `Sources/Termclip/Cleaner.swift`
- Create: `Tests/TermclipTests/CleanerTests.swift`

**Step 1: Write the failing tests**

```swift
import XCTest
@testable import termclip

final class CleanerTests: XCTestCase {

    // MARK: - Single line passthrough

    func testSingleLineStripsWhitespace() {
        let input = "  scp foo bar  "
        let result = TermclipCleaner.clean(input)
        XCTAssertEqual(result, "scp foo bar")
    }

    func testAlreadyCleanSingleLine() {
        let input = "git push origin main"
        let result = TermclipCleaner.clean(input)
        XCTAssertEqual(result, input)
    }

    // MARK: - Wrapped command joining

    func testWrappedCommandJoinsToOneLine() {
        let input = """
          scp -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 ~/.claude/settings.json
          jongrant@jons-mac-mini-2.local:~/.claude/
        """
        let result = TermclipCleaner.clean(input)
        XCTAssertEqual(result, "scp -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 ~/.claude/settings.json jongrant@jons-mac-mini-2.local:~/.claude/")
    }

    func testWrappedLongCurlCommand() {
        let input = """
          curl -X POST https://api.example.com/v1/deploy
          -H "Authorization: Bearer token123"
          -d '{"app": "termclip"}'
        """
        let result = TermclipCleaner.clean(input)
        XCTAssertEqual(result, "curl -X POST https://api.example.com/v1/deploy -H \"Authorization: Bearer token123\" -d '{\"app\": \"termclip\"}'")
    }

    // MARK: - Backslash continuations

    func testBackslashContinuationJoins() {
        let input = """
          docker run \\
            -v /host:/container \\
            -p 8080:80 \\
            nginx
        """
        let result = TermclipCleaner.clean(input)
        XCTAssertEqual(result, "docker run -v /host:/container -p 8080:80 nginx")
    }

    // MARK: - Markdown preservation

    func testMarkdownHeadingsPreserved() {
        let input = """
          ## Section Title

          Some body text here.
          - bullet one
          - bullet two
        """
        let result = TermclipCleaner.clean(input)
        XCTAssertTrue(result.contains("## Section Title"))
        XCTAssertTrue(result.contains("- bullet one"))
        XCTAssertTrue(result.contains("- bullet two"))
    }

    func testFencedCodeBlockPreserved() {
        let input = """
          ```bash
          echo "hello"
          echo "world"
          ```
        """
        let result = TermclipCleaner.clean(input)
        XCTAssertTrue(result.contains("```bash"))
        XCTAssertTrue(result.contains("echo \"hello\""))
        XCTAssertTrue(result.contains("echo \"world\""))
    }

    // MARK: - Code preservation (varying indent)

    func testCodeWithVaryingIndentPreserved() {
        let input = """
          def hello():
              print("world")
              if True:
                  return 1
        """
        let result = TermclipCleaner.clean(input)
        XCTAssertTrue(result.contains("def hello():"))
        XCTAssertTrue(result.contains("    print(\"world\")"))
        XCTAssertTrue(result.contains("        return 1"))
    }

    // MARK: - Separate commands preserved

    func testSeparateCommandsKeptAsSeparateLines() {
        let input = """
          git add .
          git commit -m "fix"
          git push
        """
        let result = TermclipCleaner.clean(input)
        XCTAssertEqual(result, "git add .\ngit commit -m \"fix\"\ngit push")
    }

    // MARK: - Blank line paragraph preservation

    func testBlankLinesSeparateParagraphs() {
        let input = """
          First paragraph that wraps
          across two lines.

          Second paragraph also
          wrapping here.
        """
        let result = TermclipCleaner.clean(input)
        XCTAssertTrue(result.contains("First paragraph that wraps across two lines."))
        XCTAssertTrue(result.contains("Second paragraph also wrapping here."))
        XCTAssertTrue(result.contains("\n\n"))
    }

    // MARK: - Empty / whitespace only

    func testEmptyStringReturnsEmpty() {
        XCTAssertEqual(TermclipCleaner.clean(""), "")
    }

    func testWhitespaceOnlyReturnsEmpty() {
        XCTAssertEqual(TermclipCleaner.clean("   \n  \n   "), "")
    }

    // MARK: - No change needed

    func testCleanTextUnchanged() {
        let input = "already clean"
        XCTAssertEqual(TermclipCleaner.clean(input), input)
        XCTAssertTrue(TermclipCleaner.isAlreadyClean(input))
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `TermclipCleaner` not defined

**Step 3: Implement Cleaner**

```swift
import Foundation

enum TermclipCleaner {

    static func clean(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        // Single line — just trim
        if !trimmed.contains("\n") {
            return trimmed
        }

        let lines = text.components(separatedBy: .newlines)

        // Check for markdown
        if containsMarkdown(lines) {
            return stripCommonIndent(lines)
        }

        // Check for fenced code blocks
        if containsFencedCodeBlock(lines) {
            return stripCommonIndent(lines)
        }

        // Process paragraphs (split on blank lines)
        let paragraphs = splitIntoParagraphs(lines)

        if paragraphs.count > 1 {
            let cleaned = paragraphs.map { cleanParagraph($0) }
            return cleaned.joined(separator: "\n\n")
        }

        // Single block — clean it
        return cleanParagraph(lines)
    }

    static func isAlreadyClean(_ text: String) -> Bool {
        return clean(text) == text
    }

    // MARK: - Paragraph cleaning

    private static func cleanParagraph(_ lines: [String]) -> String {
        let stripped = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if stripped.isEmpty { return "" }

        // Check for varying indentation (code)
        if hasVaryingIndentation(lines) {
            return stripCommonIndent(lines)
        }

        // Check if lines are separate commands
        if stripped.allSatisfy({ startsWithCommandVerb($0) }) && stripped.count > 1 {
            return stripped.joined(separator: "\n")
        }

        // Handle backslash continuations
        let joined = joinBackslashContinuations(stripped)

        // Default: join into single line
        return joined
            .joined(separator: " ")
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Detection helpers

    private static func containsMarkdown(_ lines: [String]) -> Bool {
        let stripped = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        return stripped.contains { line in
            line.hasPrefix("# ") || line.hasPrefix("## ") || line.hasPrefix("### ") ||
            line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("> ") ||
            line.hasPrefix("|") && line.contains("|") && line.hasSuffix("|")
        }
    }

    private static func containsFencedCodeBlock(_ lines: [String]) -> Bool {
        let stripped = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        return stripped.contains { $0.hasPrefix("```") }
    }

    private static func hasVaryingIndentation(_ lines: [String]) -> Bool {
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard nonEmpty.count > 1 else { return false }
        let indents = nonEmpty.map { leadingWhitespaceCount($0) }
        let uniqueIndents = Set(indents)
        return uniqueIndents.count > 1
    }

    private static func startsWithCommandVerb(_ line: String) -> Bool {
        let commandVerbs = [
            "git", "cd", "ls", "npm", "yarn", "pnpm", "docker", "kubectl",
            "ssh", "scp", "curl", "wget", "pip", "brew", "make", "cargo",
            "go", "python", "python3", "node", "ruby", "swift", "rustc",
            "cat", "echo", "mkdir", "rm", "cp", "mv", "chmod", "chown",
            "grep", "find", "sed", "awk", "export", "source", "sudo",
            "apt", "yum", "dnf", "pacman", "tar", "unzip", "zip",
        ]
        let firstWord = line.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        return commandVerbs.contains(firstWord)
    }

    private static func joinBackslashContinuations(_ lines: [String]) -> [String] {
        var result: [String] = []
        var current = ""
        for line in lines {
            if current.hasSuffix("\\") {
                current = String(current.dropLast()).trimmingCharacters(in: .whitespaces)
                current += " " + line.trimmingCharacters(in: .whitespaces)
            } else if !current.isEmpty {
                result.append(current)
                current = line
            } else {
                current = line
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    // MARK: - Utility

    private static func leadingWhitespaceCount(_ s: String) -> Int {
        return s.prefix(while: { $0 == " " || $0 == "\t" }).count
    }

    private static func stripCommonIndent(_ lines: [String]) -> String {
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !nonEmpty.isEmpty else { return "" }
        let minIndent = nonEmpty.map { leadingWhitespaceCount($0) }.min() ?? 0
        return lines
            .map { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return "" }
                return String(line.dropFirst(min(minIndent, line.count)))
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func splitIntoParagraphs(_ lines: [String]) -> [[String]] {
        var paragraphs: [[String]] = []
        var current: [String] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !current.isEmpty {
                    paragraphs.append(current)
                    current = []
                }
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { paragraphs.append(current) }
        return paragraphs
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -30`
Expected: All 12+ tests PASS

**Step 5: Commit**

```bash
git add Sources/Termclip/Cleaner.swift Tests/TermclipTests/CleanerTests.swift
git commit -m "feat: add smart cleaning heuristics engine with tests"
```

---

### Task 6: Clipboard Monitor (Daemon Core)

**Files:**
- Create: `Sources/Termclip/ClipboardMonitor.swift`

Note: This module uses AppKit APIs (NSPasteboard, NSWorkspace) which are hard to unit test without a running app. We test it via integration later.

**Step 1: Implement ClipboardMonitor**

```swift
import AppKit
import Foundation

final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let config: TermclipConfig
    private let logger: TermclipLogger
    private let onClean: ((String) -> Void)?

    init(config: TermclipConfig, logger: TermclipLogger, onClean: ((String) -> Void)? = nil) {
        self.config = config
        self.logger = logger
        self.onClean = onClean
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
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
        guard !TermclipCleaner.isAlreadyClean(text) else { return }

        let cleaned = TermclipCleaner.clean(text)
        let linesBefore = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        let linesAfter = cleaned.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count

        pasteboard.clearContents()
        pasteboard.setString(cleaned, forType: .string)
        lastChangeCount = pasteboard.changeCount // Don't re-trigger on our own write

        try? logger.log(app: frontmostAppName(), original: text, cleaned: cleaned, linesBefore: linesBefore, linesAfter: linesAfter)
        onClean?(cleaned)
    }

    private func isTerminalFrontmost() -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return config.terminalBundleIDs.contains(bundleID)
    }

    private func frontmostAppName() -> String {
        return NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
    }
}
```

**Step 2: Build to verify it compiles**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/Termclip/ClipboardMonitor.swift
git commit -m "feat: add clipboard monitor with terminal detection"
```

---

### Task 7: Notification Support

**Files:**
- Create: `Sources/Termclip/Notifier.swift`

**Step 1: Implement Notifier**

```swift
import Foundation
import UserNotifications

final class TermclipNotifier {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    static func send(cleanedText: String) {
        let content = UNMutableNotificationContent()
        content.title = "Termclip"
        content.body = String(cleanedText.prefix(60)) + (cleanedText.count > 60 ? "..." : "")
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
```

**Step 2: Build to verify it compiles**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/Termclip/Notifier.swift
git commit -m "feat: add macOS notification support"
```

---

### Task 8: Daemon Lifecycle (PID file, start/stop)

**Files:**
- Create: `Sources/Termclip/Daemon.swift`
- Create: `Tests/TermclipTests/DaemonTests.swift`

**Step 1: Write the failing tests**

```swift
import XCTest
@testable import termclip

final class DaemonTests: XCTestCase {
    let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("termclip-daemon-test-\(UUID().uuidString)")

    override func setUp() {
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
    }

    func testWriteAndReadPID() throws {
        let pidFile = testDir.appendingPathComponent("test.pid")
        try DaemonManager.writePID(ProcessInfo.processInfo.processIdentifier, to: pidFile)
        let readPID = try DaemonManager.readPID(from: pidFile)
        XCTAssertEqual(readPID, ProcessInfo.processInfo.processIdentifier)
    }

    func testIsRunningReturnsFalseForBogus() throws {
        let pidFile = testDir.appendingPathComponent("test.pid")
        try DaemonManager.writePID(99999, to: pidFile)
        // PID 99999 is almost certainly not running
        XCTAssertFalse(DaemonManager.isRunning(pidFile: pidFile))
    }

    func testIsRunningReturnsFalseForMissingFile() {
        let pidFile = testDir.appendingPathComponent("nonexistent.pid")
        XCTAssertFalse(DaemonManager.isRunning(pidFile: pidFile))
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `DaemonManager` not defined

**Step 3: Implement DaemonManager**

```swift
import Foundation

enum DaemonManager {
    static func writePID(_ pid: Int32, to url: URL) throws {
        try "\(pid)".write(to: url, atomically: true, encoding: .utf8)
    }

    static func readPID(from url: URL) throws -> Int32 {
        let contents = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pid = Int32(contents) else {
            throw TermclipError.invalidPIDFile
        }
        return pid
    }

    static func isRunning(pidFile: URL) -> Bool {
        guard let pid = try? readPID(from: pidFile) else { return false }
        return kill(pid, 0) == 0
    }

    static func stopRunning(pidFile: URL) throws {
        let pid = try readPID(from: pidFile)
        kill(pid, SIGTERM)
        try? FileManager.default.removeItem(at: pidFile)
    }

    static func removeStalePID(pidFile: URL) {
        if !isRunning(pidFile: pidFile) {
            try? FileManager.default.removeItem(at: pidFile)
        }
    }
}

enum TermclipError: Error, LocalizedError {
    case invalidPIDFile
    case alreadyRunning
    case notRunning

    var errorDescription: String? {
        switch self {
        case .invalidPIDFile: return "Invalid PID file"
        case .alreadyRunning: return "Termclip is already running"
        case .notRunning: return "Termclip is not running"
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -20`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add Sources/Termclip/Daemon.swift Tests/TermclipTests/DaemonTests.swift
git commit -m "feat: add daemon lifecycle management with PID file"
```

---

### Task 9: Launchd Integration

**Files:**
- Create: `Sources/Termclip/Launchd.swift`

**Step 1: Implement launchd plist generation**

```swift
import Foundation

enum LaunchdManager {
    static func install() throws {
        let binaryPath = ProcessInfo.processInfo.arguments[0]
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.termclip.agent</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
                <string>start</string>
                <string>--foreground</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
            <key>StandardOutPath</key>
            <string>\(TermclipPaths.baseDir.path)/stdout.log</string>
            <key>StandardErrorPath</key>
            <string>\(TermclipPaths.baseDir.path)/stderr.log</string>
        </dict>
        </plist>
        """
        try plist.write(to: TermclipPaths.launchdPlist, atomically: true, encoding: .utf8)
    }

    static func uninstall() throws {
        if FileManager.default.fileExists(atPath: TermclipPaths.launchdPlist.path) {
            // Unload first
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["unload", TermclipPaths.launchdPlist.path]
            try? process.run()
            process.waitUntilExit()
            try FileManager.default.removeItem(at: TermclipPaths.launchdPlist)
        }
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: TermclipPaths.launchdPlist.path)
    }
}
```

**Step 2: Build to verify it compiles**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/Termclip/Launchd.swift
git commit -m "feat: add launchd plist install/uninstall for auto-start"
```

---

### Task 10: CLI Command Router

**Files:**
- Modify: `Sources/Termclip/main.swift`

**Step 1: Replace main.swift with full CLI**

```swift
import AppKit
import Foundation

@main
struct TermclipCLI {
    static func main() {
        let args = CommandLine.arguments.dropFirst()
        let command = args.first ?? "help"
        let subargs = Array(args.dropFirst())

        do {
            switch command {
            case "start":
                try startDaemon(foreground: subargs.contains("--foreground"))
            case "stop":
                try stopDaemon()
            case "status":
                showStatus()
            case "notifications":
                try setNotifications(subargs.first)
            case "log":
                try showLog()
            case "enable":
                try enableAutostart()
            case "disable":
                try disableAutostart()
            case "version":
                print("termclip v0.1.0")
            case "help", "--help", "-h":
                printUsage()
            default:
                print("Unknown command: \(command)")
                printUsage()
                exit(1)
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }

    // MARK: - Commands

    static func startDaemon(foreground: Bool) throws {
        try TermclipPaths.ensureDirectory(TermclipPaths.baseDir)
        DaemonManager.removeStalePID(pidFile: TermclipPaths.pidFile)

        if DaemonManager.isRunning(pidFile: TermclipPaths.pidFile) {
            throw TermclipError.alreadyRunning
        }

        if !foreground {
            // Fork to background
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
            process.arguments = ["start", "--foreground"]
            try process.run()
            print("Termclip started (PID: \(process.processIdentifier))")
            return
        }

        // Foreground mode — run the daemon
        let config = (try? TermclipConfig.load(from: TermclipPaths.configFile)) ?? .defaultConfig
        let logger = TermclipLogger(file: TermclipPaths.logFile)
        try DaemonManager.writePID(ProcessInfo.processInfo.processIdentifier, to: TermclipPaths.pidFile)

        if config.notificationsEnabled {
            TermclipNotifier.requestPermission()
        }

        let monitor = ClipboardMonitor(config: config, logger: logger) { cleaned in
            if config.notificationsEnabled {
                TermclipNotifier.send(cleanedText: cleaned)
            }
        }

        // Handle SIGTERM gracefully
        signal(SIGTERM) { _ in
            try? FileManager.default.removeItem(at: TermclipPaths.pidFile)
            exit(0)
        }

        monitor.start()
        RunLoop.current.run()
    }

    static func stopDaemon() throws {
        guard DaemonManager.isRunning(pidFile: TermclipPaths.pidFile) else {
            throw TermclipError.notRunning
        }
        try DaemonManager.stopRunning(pidFile: TermclipPaths.pidFile)
        print("Termclip stopped")
    }

    static func showStatus() {
        let running = DaemonManager.isRunning(pidFile: TermclipPaths.pidFile)
        let config = (try? TermclipConfig.load(from: TermclipPaths.configFile)) ?? .defaultConfig
        let autostart = LaunchdManager.isInstalled

        print("Termclip status:")
        print("  Running:       \(running ? "yes" : "no")")
        if running, let pid = try? DaemonManager.readPID(from: TermclipPaths.pidFile) {
            print("  PID:           \(pid)")
        }
        print("  Notifications: \(config.notificationsEnabled ? "on" : "off")")
        print("  Auto-start:    \(autostart ? "enabled" : "disabled")")
    }

    static func setNotifications(_ value: String?) throws {
        guard let value = value, ["on", "off"].contains(value) else {
            print("Usage: termclip notifications <on|off>")
            exit(1)
        }
        try TermclipPaths.ensureDirectory(TermclipPaths.baseDir)
        var config = (try? TermclipConfig.load(from: TermclipPaths.configFile)) ?? .defaultConfig
        config.notificationsEnabled = (value == "on")
        try config.save(to: TermclipPaths.configFile)
        print("Notifications \(value)")
        if value == "on" {
            TermclipNotifier.requestPermission()
        }
    }

    static func showLog() throws {
        let logger = TermclipLogger(file: TermclipPaths.logFile)
        let entries = try logger.recent(count: 20)
        if entries.isEmpty {
            print("No cleaning activity yet.")
        } else {
            entries.forEach { print($0) }
        }
    }

    static func enableAutostart() throws {
        try TermclipPaths.ensureDirectory(TermclipPaths.baseDir)
        try LaunchdManager.install()
        print("Auto-start enabled. Termclip will start on login.")
    }

    static func disableAutostart() throws {
        try LaunchdManager.uninstall()
        print("Auto-start disabled.")
    }

    static func printUsage() {
        print("""
        Termclip - Auto-clean clipboard text from terminal apps

        Usage: termclip <command>

        Commands:
          start                Start the Termclip daemon
          stop                 Stop the running daemon
          status               Show current status
          notifications <on|off>  Toggle macOS notifications
          log                  Show recent cleaning activity
          enable               Enable auto-start on login
          disable              Disable auto-start on login
          version              Show version
          help                 Show this help
        """)
    }
}
```

Note: Remove the `@main` attribute and use top-level code in `main.swift` since this is an executable target. The struct approach requires `@main` which needs `static func main()` but for simplicity use top-level code — call `TermclipCLI.main()` at the bottom of the file instead, or restructure as top-level code.

**Step 2: Build and test help output**

Run: `swift build 2>&1 && .build/debug/termclip help`
Expected: Build succeeds, prints usage

**Step 3: Commit**

```bash
git add Sources/Termclip/main.swift
git commit -m "feat: add CLI command router with all subcommands"
```

---

### Task 11: Integration Test — End to End

**Files:**
- Create: `Tests/TermclipTests/IntegrationTests.swift`

**Step 1: Write integration tests for the cleaner with real-world examples**

```swift
import XCTest
@testable import termclip

final class IntegrationTests: XCTestCase {

    // Real-world Claude Code output examples
    func testClaudeCodeSCPCommand() {
        let input = """
          scp -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 ~/.claude/settings.json ~/.claude/statusline-command.sh
          jongrant@jons-mac-mini-2.local:~/.claude/
        """
        let result = TermclipCleaner.clean(input)
        XCTAssertFalse(result.contains("\n"))
        XCTAssertTrue(result.hasPrefix("scp"))
        XCTAssertTrue(result.hasSuffix("~/.claude/"))
    }

    func testClaudeCodeDockerCommand() {
        let input = """
          docker run --rm -it \\
            -v $(pwd):/app \\
            -w /app \\
            -p 3000:3000 \\
            node:18 npm start
        """
        let result = TermclipCleaner.clean(input)
        XCTAssertFalse(result.contains("\\"))
        XCTAssertTrue(result.hasPrefix("docker"))
    }

    func testClaudeCodeMarkdownOutput() {
        let input = """
          ## Installation

          1. Clone the repo
          2. Run `swift build`
          3. Copy binary to PATH

          ```bash
          swift build -c release
          cp .build/release/termclip /usr/local/bin/
          ```
        """
        let result = TermclipCleaner.clean(input)
        XCTAssertTrue(result.contains("## Installation"))
        XCTAssertTrue(result.contains("1. Clone the repo"))
        XCTAssertTrue(result.contains("```bash"))
    }

    func testClaudeCodeGitSequence() {
        let input = """
          git add .
          git commit -m "initial commit"
          git push -u origin main
        """
        let result = TermclipCleaner.clean(input)
        let lines = result.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[0].hasPrefix("git add"))
        XCTAssertTrue(lines[1].hasPrefix("git commit"))
        XCTAssertTrue(lines[2].hasPrefix("git push"))
    }

    func testClaudeCodePythonSnippet() {
        let input = """
          def fibonacci(n):
              if n <= 1:
                  return n
              return fibonacci(n-1) + fibonacci(n-2)
        """
        let result = TermclipCleaner.clean(input)
        XCTAssertTrue(result.contains("def fibonacci(n):"))
        XCTAssertTrue(result.contains("    if n <= 1:"))
    }
}
```

**Step 2: Run all tests**

Run: `swift test 2>&1 | tail -30`
Expected: ALL tests PASS

**Step 3: Commit**

```bash
git add Tests/TermclipTests/IntegrationTests.swift
git commit -m "test: add integration tests with real-world Claude Code examples"
```

---

### Task 12: Build Release Binary and Test CLI

**Step 1: Build release binary**

Run: `swift build -c release 2>&1`
Expected: Build succeeds

**Step 2: Test CLI commands**

Run: `.build/release/termclip version`
Expected: `termclip v0.1.0`

Run: `.build/release/termclip help`
Expected: Usage text

Run: `.build/release/termclip status`
Expected: Shows status (not running)

**Step 3: Test start/stop cycle**

Run: `.build/release/termclip start && sleep 1 && .build/release/termclip status && .build/release/termclip stop`
Expected: Starts, shows running, stops

**Step 4: Commit and push**

```bash
git add -A
git commit -m "chore: release build verification"
git push
```

---

### Task 13: Install Locally and Replace Shell Function

**Step 1: Copy to PATH**

Run: `cp .build/release/termclip /usr/local/bin/termclip`

**Step 2: Remove old termclip function from .zshrc**

Remove the `termclip()` shell function from `~/.zshrc` since the binary now replaces it.

**Step 3: Verify installed binary**

Run: `which termclip && termclip version`
Expected: `/usr/local/bin/termclip` and `termclip v0.1.0`

**Step 4: Commit .zshrc change**

```bash
git commit -m "chore: remove shell function, replaced by native binary"
```
