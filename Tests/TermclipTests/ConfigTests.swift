import Foundation
import Testing
@testable import termclip

struct ConfigTests {
    let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("termclip-test-\(UUID().uuidString)")

    init() throws {
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    @Test func defaultConfig() {
        let config = TermclipConfig.defaultConfig
        #expect(config.notificationsEnabled == false)
        #expect(config.terminalBundleIDs.contains("com.apple.Terminal"))
        #expect(config.terminalBundleIDs.contains("com.googlecode.iterm2"))
    }

    @Test func saveAndLoad() throws {
        let configPath = testDir.appendingPathComponent("config.json")
        var config = TermclipConfig.defaultConfig
        config.notificationsEnabled = true
        try config.save(to: configPath)
        let loaded = try TermclipConfig.load(from: configPath)
        #expect(loaded.notificationsEnabled == true)
        #expect(loaded.terminalBundleIDs == config.terminalBundleIDs)
    }

    @Test func loadMissingFileReturnsDefault() {
        let missing = testDir.appendingPathComponent("nonexistent.json")
        let config = (try? TermclipConfig.load(from: missing)) ?? .defaultConfig
        #expect(config.notificationsEnabled == false)
    }
}
