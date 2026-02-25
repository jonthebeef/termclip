import Foundation

final class TermclipLogger: Sendable {
    let file: URL
    let maxEntries: Int

    init(file: URL, maxEntries: Int = 1000) {
        self.file = file
        self.maxEntries = maxEntries
    }

    func log(app: String, original: String, cleaned: String, linesBefore: Int, linesAfter: Int) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let preview = String(cleaned.prefix(60))
        let entry = "[\(timestamp)] Cleaned from \(app): \"\(preview)\" (\(linesBefore) lines → \(linesAfter))"

        var lines = (try? String(contentsOf: file, encoding: .utf8))?
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty } ?? []
        lines.append(entry)

        if lines.count > maxEntries {
            lines = Array(lines.suffix(maxEntries))
        }

        try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
    }

    func recent(count: Int = 20) throws -> [String] {
        guard FileManager.default.fileExists(atPath: file.path) else {
            return []
        }
        let contents = try String(contentsOf: file, encoding: .utf8)
        let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return Array(lines.suffix(count))
    }
}
