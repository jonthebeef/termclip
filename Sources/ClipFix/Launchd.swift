import Foundation

enum LaunchdManager {
    static func install() throws {
        let binaryPath = ProcessInfo.processInfo.arguments[0]
        let baseDir = ClipFixPaths.baseDir.path

        let plist: [String: Any] = [
            "Label": "com.clipfix.agent",
            "ProgramArguments": [binaryPath, "start", "--foreground"],
            "RunAtLoad": true,
            "KeepAlive": false,
            "StandardOutPath": "\(baseDir)/stdout.log",
            "StandardErrorPath": "\(baseDir)/stderr.log",
        ]

        // Ensure LaunchAgents directory exists
        let launchAgentsDir = ClipFixPaths.launchdPlist.deletingLastPathComponent()
        try ClipFixPaths.ensureDirectory(launchAgentsDir)

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: ClipFixPaths.launchdPlist, options: .atomic)
    }

    static func uninstall() throws {
        if FileManager.default.fileExists(atPath: ClipFixPaths.launchdPlist.path) {
            // Unload first
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["unload", ClipFixPaths.launchdPlist.path]
            try? process.run()
            process.waitUntilExit()
            try FileManager.default.removeItem(at: ClipFixPaths.launchdPlist)
        }
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: ClipFixPaths.launchdPlist.path)
    }
}
