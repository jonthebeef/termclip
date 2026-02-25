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
