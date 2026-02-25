import Testing
import Foundation
@testable import termclip

struct LoggerTests {
    @Test func logWritesEntry() throws {
        let testLogFile = FileManager.default.temporaryDirectory.appendingPathComponent("termclip-log-test-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: testLogFile) }

        let logger = TermclipLogger(file: testLogFile)
        try logger.log(app: "iTerm2", original: "  scp foo\n  bar", cleaned: "scp foo bar", linesBefore: 2, linesAfter: 1)
        let contents = try String(contentsOf: testLogFile, encoding: .utf8)
        #expect(contents.contains("iTerm2"))
        #expect(contents.contains("2 lines → 1"))
        #expect(contents.contains("scp foo bar"))
    }

    @Test func logCapsAtMaxEntries() throws {
        let testLogFile = FileManager.default.temporaryDirectory.appendingPathComponent("termclip-log-test-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: testLogFile) }

        let logger = TermclipLogger(file: testLogFile, maxEntries: 10)
        for i in 0..<15 {
            try logger.log(app: "Term", original: "line \(i)", cleaned: "line \(i)", linesBefore: 1, linesAfter: 1)
        }
        let contents = try String(contentsOf: testLogFile, encoding: .utf8)
        let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        #expect(lines.count == 10)
        #expect(contents.contains("line 14"))
        #expect(!contents.contains("line 0"))
    }

    @Test func recentReturnsLastN() throws {
        let testLogFile = FileManager.default.temporaryDirectory.appendingPathComponent("termclip-log-test-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: testLogFile) }

        let logger = TermclipLogger(file: testLogFile)
        for i in 0..<5 {
            try logger.log(app: "Term", original: "cmd \(i)", cleaned: "cmd \(i)", linesBefore: 1, linesAfter: 1)
        }
        let recent = try logger.recent(count: 3)
        #expect(recent.count == 3)
        #expect(recent.last!.contains("cmd 4"))
    }
}
