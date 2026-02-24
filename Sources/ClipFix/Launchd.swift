import Foundation

enum LaunchdManager {
    static func install() throws {
        let binaryPath = ProcessInfo.processInfo.arguments[0]
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.clipfix.agent</string>
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
            <string>\(ClipFixPaths.baseDir.path)/stdout.log</string>
            <key>StandardErrorPath</key>
            <string>\(ClipFixPaths.baseDir.path)/stderr.log</string>
        </dict>
        </plist>
        """

        // Ensure LaunchAgents directory exists
        let launchAgentsDir = ClipFixPaths.launchdPlist.deletingLastPathComponent()
        try ClipFixPaths.ensureDirectory(launchAgentsDir)

        try plist.write(to: ClipFixPaths.launchdPlist, atomically: true, encoding: .utf8)
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
