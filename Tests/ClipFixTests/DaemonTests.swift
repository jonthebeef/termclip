import Testing
import Foundation
@testable import clipfix

struct DaemonTests {
    @Test func writeAndReadPID() throws {
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("clipfix-daemon-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testDir) }

        let pidFile = testDir.appendingPathComponent("test.pid")
        try DaemonManager.writePID(ProcessInfo.processInfo.processIdentifier, to: pidFile)
        let readPID = try DaemonManager.readPID(from: pidFile)
        #expect(readPID == ProcessInfo.processInfo.processIdentifier)
    }

    @Test func isRunningReturnsFalseForBogus() throws {
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("clipfix-daemon-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testDir) }

        let pidFile = testDir.appendingPathComponent("test.pid")
        try DaemonManager.writePID(99999, to: pidFile)
        #expect(!DaemonManager.isRunning(pidFile: pidFile))
    }

    @Test func isRunningReturnsFalseForMissingFile() {
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("clipfix-daemon-test-\(UUID().uuidString)")
        let pidFile = testDir.appendingPathComponent("nonexistent.pid")
        #expect(!DaemonManager.isRunning(pidFile: pidFile))
    }
}
