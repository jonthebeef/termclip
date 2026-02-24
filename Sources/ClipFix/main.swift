import AppKit
import Foundation

let args = Array(CommandLine.arguments.dropFirst())
let command = args.first ?? "help"
let subargs = Array(args.dropFirst())

@MainActor func startDaemon(foreground: Bool) throws {
    try ClipFixPaths.ensureDirectory(ClipFixPaths.baseDir)
    DaemonManager.removeStalePID(pidFile: ClipFixPaths.pidFile)

    if DaemonManager.isRunning(pidFile: ClipFixPaths.pidFile) {
        throw ClipFixError.alreadyRunning
    }

    if !foreground {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        process.arguments = ["start", "--foreground"]
        try process.run()
        print("ClipFix started (PID: \(process.processIdentifier))")
        return
    }

    // Foreground mode — run the daemon
    let config = (try? ClipFixConfig.load(from: ClipFixPaths.configFile)) ?? .defaultConfig
    let logger = ClipFixLogger(file: ClipFixPaths.logFile)
    try DaemonManager.writePID(ProcessInfo.processInfo.processIdentifier, to: ClipFixPaths.pidFile)

    if config.notificationsEnabled {
        ClipFixNotifier.requestPermission()
    }

    let monitor = ClipboardMonitor(config: config, logger: logger) { cleaned in
        if config.notificationsEnabled {
            ClipFixNotifier.send(cleanedText: cleaned)
        }
    }

    // Ignore default SIGTERM handling
    signal(SIGTERM, SIG_IGN)

    // Handle SIGTERM via dispatch source (safe to use Swift APIs)
    let sigSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    sigSource.setEventHandler {
        try? FileManager.default.removeItem(at: ClipFixPaths.pidFile)
        exit(0)
    }
    sigSource.resume()

    monitor.start()
    RunLoop.current.run()
}

func stopDaemon() throws {
    guard DaemonManager.isRunning(pidFile: ClipFixPaths.pidFile) else {
        throw ClipFixError.notRunning
    }
    try DaemonManager.stopRunning(pidFile: ClipFixPaths.pidFile)
    print("ClipFix stopped")
}

func showStatus() {
    let running = DaemonManager.isRunning(pidFile: ClipFixPaths.pidFile)
    let config = (try? ClipFixConfig.load(from: ClipFixPaths.configFile)) ?? .defaultConfig
    let autostart = LaunchdManager.isInstalled

    print("ClipFix status:")
    print("  Running:       \(running ? "yes" : "no")")
    if running, let pid = try? DaemonManager.readPID(from: ClipFixPaths.pidFile) {
        print("  PID:           \(pid)")
    }
    print("  Notifications: \(config.notificationsEnabled ? "on" : "off")")
    print("  Auto-start:    \(autostart ? "enabled" : "disabled")")
}

func setNotifications(_ value: String?) throws {
    guard let value = value, ["on", "off"].contains(value) else {
        print("Usage: clipfix notifications <on|off>")
        exit(1)
    }
    try ClipFixPaths.ensureDirectory(ClipFixPaths.baseDir)
    var config = (try? ClipFixConfig.load(from: ClipFixPaths.configFile)) ?? .defaultConfig
    config.notificationsEnabled = (value == "on")
    try config.save(to: ClipFixPaths.configFile)
    print("Notifications \(value)")
}

func showLog() throws {
    let logger = ClipFixLogger(file: ClipFixPaths.logFile)
    let entries = try logger.recent(count: 20)
    if entries.isEmpty {
        print("No cleaning activity yet.")
    } else {
        entries.forEach { print($0) }
    }
}

func enableAutostart() throws {
    try ClipFixPaths.ensureDirectory(ClipFixPaths.baseDir)
    try LaunchdManager.install()
    print("Auto-start enabled. ClipFix will start on login.")
}

func disableAutostart() throws {
    try LaunchdManager.uninstall()
    print("Auto-start disabled.")
}

func printUsage() {
    print("""
    ClipFix - Auto-clean clipboard text from terminal apps

    Usage: clipfix <command>

    Commands:
      start                Start the ClipFix daemon
      stop                 Stop the running daemon
      status               Show current status
      notifications <on|off>  Toggle macOS notifications
      log                  Show recent cleaning activity
      enable               Enable auto-start on login
      disable              Disable auto-start on login
      version              Show version
      help                 Show this help
    """)
}

// Main dispatch
do {
    switch command {
    case "start":
        try startDaemon(foreground: subargs.contains("--foreground"))
    case "stop":
        try stopDaemon()
    case "status":
        showStatus()
    case "notifications":
        try setNotifications(subargs.first)
    case "log":
        try showLog()
    case "enable":
        try enableAutostart()
    case "disable":
        try disableAutostart()
    case "version":
        print("clipfix v0.1.0")
    case "help", "--help", "-h":
        printUsage()
    default:
        print("Unknown command: \(command)")
        printUsage()
        exit(1)
    }
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
