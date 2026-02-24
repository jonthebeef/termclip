import Foundation

enum DaemonManager {
    static func writePID(_ pid: Int32, to url: URL) throws {
        try "\(pid)".write(to: url, atomically: true, encoding: .utf8)
    }

    static func readPID(from url: URL) throws -> Int32 {
        let contents = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pid = Int32(contents) else {
            throw ClipFixError.invalidPIDFile
        }
        return pid
    }

    static func isRunning(pidFile: URL) -> Bool {
        guard let pid = try? readPID(from: pidFile) else { return false }
        return kill(pid, 0) == 0
    }

    static func stopRunning(pidFile: URL) throws {
        let pid = try readPID(from: pidFile)
        kill(pid, SIGTERM)
        try? FileManager.default.removeItem(at: pidFile)
    }

    static func removeStalePID(pidFile: URL) {
        if !isRunning(pidFile: pidFile) {
            try? FileManager.default.removeItem(at: pidFile)
        }
    }
}

enum ClipFixError: Error, LocalizedError {
    case invalidPIDFile
    case alreadyRunning
    case notRunning

    var errorDescription: String? {
        switch self {
        case .invalidPIDFile: return "Invalid PID file"
        case .alreadyRunning: return "ClipFix is already running"
        case .notRunning: return "ClipFix is not running"
        }
    }
}
