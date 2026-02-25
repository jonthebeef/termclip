import Testing
import Foundation
@testable import termclip

struct PathsTests {
    @Test func pathsPointToTermclipDir() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let expected = home.appendingPathComponent(".termclip")
        #expect(TermclipPaths.baseDir == expected)
        #expect(TermclipPaths.configFile == expected.appendingPathComponent("config.json"))
        #expect(TermclipPaths.pidFile == expected.appendingPathComponent("termclip.pid"))
        #expect(TermclipPaths.logFile == expected.appendingPathComponent("termclip.log"))
    }

    @Test func ensureDirectoryCreatesDir() throws {
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("termclip-paths-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testDir) }
        #expect(!FileManager.default.fileExists(atPath: testDir.path))
        try TermclipPaths.ensureDirectory(testDir)
        #expect(FileManager.default.fileExists(atPath: testDir.path))
    }
}
