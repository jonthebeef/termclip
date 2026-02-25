import Foundation

enum LaunchdManager {
    static func install() throws {
        let binaryPath = ProcessInfo.processInfo.arguments[0]
        let baseDir = TermclipPaths.baseDir.path

        let plist: [String: Any] = [
            "Label": "com.termclip.agent",
            "ProgramArguments": [binaryPath, "start", "--foreground"],
            "RunAtLoad": true,
            "KeepAlive": false,
            "StandardOutPath": "\(baseDir)/stdout.log",
            "StandardErrorPath": "\(baseDir)/stderr.log",
        ]

        // Ensure LaunchAgents directory exists
        let launchAgentsDir = TermclipPaths.launchdPlist.deletingLastPathComponent()
        try TermclipPaths.ensureDirectory(launchAgentsDir)

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: TermclipPaths.launchdPlist, options: .atomic)
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
