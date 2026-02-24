import Testing
import Foundation
@testable import clipfix

struct PathsTests {
    @Test func pathsPointToClipfixDir() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let expected = home.appendingPathComponent(".clipfix")
        #expect(ClipFixPaths.baseDir == expected)
        #expect(ClipFixPaths.configFile == expected.appendingPathComponent("config.json"))
        #expect(ClipFixPaths.pidFile == expected.appendingPathComponent("clipfix.pid"))
        #expect(ClipFixPaths.logFile == expected.appendingPathComponent("clipfix.log"))
    }

    @Test func ensureDirectoryCreatesDir() throws {
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("clipfix-paths-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDir) }
        #expect(!FileManager.default.fileExists(atPath: testDir.path))
        try ClipFixPaths.ensureDirectory(testDir)
        #expect(FileManager.default.fileExists(atPath: testDir.path))
    }
}
