import Foundation

enum ClipFixPaths {
    static let baseDir: URL = {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".clipfix")
    }()

    static let configFile = baseDir.appendingPathComponent("config.json")
    static let pidFile = baseDir.appendingPathComponent("clipfix.pid")
    static let logFile = baseDir.appendingPathComponent("clipfix.log")

    static let launchdPlist: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.clipfix.agent.plist")
    }()

    static func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
