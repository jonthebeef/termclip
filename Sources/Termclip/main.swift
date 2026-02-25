import AppKit
import Foundation

let args = Array(CommandLine.arguments.dropFirst())
let command = args.first ?? "help"
let subargs = Array(args.dropFirst())

@MainActor func startDaemon(foreground: Bool) throws {
    try TermclipPaths.ensureDirectory(TermclipPaths.baseDir)
    DaemonManager.removeStalePID(pidFile: TermclipPaths.pidFile)

    if DaemonManager.isRunning(pidFile: TermclipPaths.pidFile) {
        throw TermclipError.alreadyRunning
    }

    if !foreground {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        process.arguments = ["start", "--foreground"]
        try process.run()
        print("Termclip started (PID: \(process.processIdentifier))")
        return
    }

    // Foreground mode — run the daemon
    let config = (try? TermclipConfig.load(from: TermclipPaths.configFile)) ?? .defaultConfig
    let logger = TermclipLogger(file: TermclipPaths.logFile)
    try DaemonManager.writePID(ProcessInfo.processInfo.processIdentifier, to: TermclipPaths.pidFile)

    if config.notificationsEnabled {
        TermclipNotifier.requestPermission()
    }

    let monitor = ClipboardMonitor(config: config, logger: logger) { cleaned in
        if config.notificationsEnabled {
            TermclipNotifier.send(cleanedText: cleaned)
        }
    }

    // Ignore default SIGTERM handling
    signal(SIGTERM, SIG_IGN)

    // Handle SIGTERM via dispatch source (safe to use Swift APIs)
    let sigSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    sigSource.setEventHandler {
        try? FileManager.default.removeItem(at: TermclipPaths.pidFile)
        exit(0)
    }
    sigSource.resume()

    monitor.start()
    RunLoop.current.run()
}

func stopDaemon() throws {
    guard DaemonManager.isRunning(pidFile: TermclipPaths.pidFile) else {
        throw TermclipError.notRunning
    }
    try DaemonManager.stopRunning(pidFile: TermclipPaths.pidFile)
    print("Termclip stopped")
}

func showStatus() {
    let running = DaemonManager.isRunning(pidFile: TermclipPaths.pidFile)
    let config = (try? TermclipConfig.load(from: TermclipPaths.configFile)) ?? .defaultConfig
    let autostart = LaunchdManager.isInstalled

    print("Termclip status:")
    print("  Running:       \(running ? "yes" : "no")")
    if running, let pid = try? DaemonManager.readPID(from: TermclipPaths.pidFile) {
        print("  PID:           \(pid)")
    }
    print("  Notifications: \(config.notificationsEnabled ? "on" : "off")")
    print("  Auto-start:    \(autostart ? "enabled" : "disabled")")
}

func setNotifications(_ value: String?) throws {
    guard let value = value, ["on", "off"].contains(value) else {
        print("Usage: termclip notifications <on|off>")
        exit(1)
    }
    try TermclipPaths.ensureDirectory(TermclipPaths.baseDir)
    var config = (try? TermclipConfig.load(from: TermclipPaths.configFile)) ?? .defaultConfig
    config.notificationsEnabled = (value == "on")
    try config.save(to: TermclipPaths.configFile)
    print("Notifications \(value)")
}

func showLog() throws {
    let logger = TermclipLogger(file: TermclipPaths.logFile)
    let entries = try logger.recent(count: 20)
    if entries.isEmpty {
        print("No cleaning activity yet.")
    } else {
        entries.forEach { print($0) }
    }
}

func enableAutostart() throws {
    try TermclipPaths.ensureDirectory(TermclipPaths.baseDir)
    try LaunchdManager.install()
    print("Auto-start enabled. Termclip will start on login.")
}

func disableAutostart() throws {
    try LaunchdManager.uninstall()
    print("Auto-start disabled.")
}

func printUsage() {
    print("""
    Termclip - Auto-clean clipboard text from terminal apps

    Usage: termclip <command>

    Commands:
      start                Start the Termclip daemon
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
        print("termclip v0.1.0")
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
