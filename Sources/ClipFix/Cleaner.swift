import Foundation

enum ClipFixCleaner {

    static func clean(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        // Single line — just trim
        if !trimmed.contains("\n") {
            return trimmed
        }

        let lines = text.components(separatedBy: .newlines)

        // Check for markdown
        if containsMarkdown(lines) {
            return stripCommonIndent(lines)
        }

        // Check for fenced code blocks
        if containsFencedCodeBlock(lines) {
            return stripCommonIndent(lines)
        }

        // Check for backslash continuations — these naturally have varying
        // indentation so must be detected before the varying-indent code check
        if containsBackslashContinuations(lines) {
            return cleanParagraph(lines)
        }

        // Check for varying indentation (code) before paragraph splitting
        if hasVaryingIndentation(lines) {
            return stripCommonIndent(lines)
        }

        // Process paragraphs (split on blank lines)
        let paragraphs = splitIntoParagraphs(lines)

        if paragraphs.count > 1 {
            let cleaned = paragraphs.map { cleanParagraph($0) }
            return cleaned.joined(separator: "\n\n")
        }

        // Single block — clean it
        return cleanParagraph(lines)
    }

    static func isAlreadyClean(_ text: String) -> Bool {
        return clean(text) == text
    }

    // MARK: - Paragraph cleaning

    private static func cleanParagraph(_ lines: [String]) -> String {
        let stripped = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if stripped.isEmpty { return "" }

        // Handle backslash continuations before varying-indent check
        if containsBackslashContinuations(lines) {
            let joined = joinBackslashContinuations(stripped)
            return joined
                .joined(separator: " ")
                .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }

        // Check for varying indentation (code)
        if hasVaryingIndentation(lines) {
            return stripCommonIndent(lines)
        }

        // Check if lines are separate commands
        if stripped.allSatisfy({ startsWithCommandVerb($0) }) && stripped.count > 1 {
            return stripped.joined(separator: "\n")
        }

        // Handle remaining lines
        let joined = joinBackslashContinuations(stripped)

        // Default: join into single line
        return joined
            .joined(separator: " ")
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Detection helpers

    private static func containsMarkdown(_ lines: [String]) -> Bool {
        let stripped = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        var indicators = 0
        for line in stripped {
            if line.hasPrefix("# ") || line.hasPrefix("## ") || line.hasPrefix("### ") ||
               line.hasPrefix("#### ") || line.hasPrefix("##### ") || line.hasPrefix("###### ") {
                indicators += 1
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("> ") {
                indicators += 1
            } else if line.hasPrefix("|") && line.contains("|") && line.hasSuffix("|") {
                indicators += 1
            } else if line.hasPrefix("```") {
                indicators += 1
            }
            if indicators >= 2 { return true }
        }
        return false
    }

    private static func containsBackslashContinuations(_ lines: [String]) -> Bool {
        let stripped = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        return stripped.contains { line in
            line.hasSuffix(" \\") || line == "\\"
        }
    }

    private static func containsFencedCodeBlock(_ lines: [String]) -> Bool {
        let stripped = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        return stripped.contains { $0.hasPrefix("```") }
    }

    private static func hasVaryingIndentation(_ lines: [String]) -> Bool {
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard nonEmpty.count > 1 else { return false }
        let indents = nonEmpty.map { leadingWhitespaceCount($0) }
        let minIndent = indents.min() ?? 0
        let maxIndent = indents.max() ?? 0
        return (maxIndent - minIndent) >= 2
    }

    private static let commandVerbs: Set<String> = [
        "git", "cd", "ls", "npm", "yarn", "pnpm", "docker", "kubectl",
        "ssh", "scp", "curl", "wget", "pip", "brew", "make", "cargo",
        "go", "python", "python3", "node", "ruby", "swift", "rustc",
        "cat", "echo", "mkdir", "rm", "cp", "mv", "chmod", "chown",
        "grep", "find", "sed", "awk", "export", "source", "sudo",
        "apt", "yum", "dnf", "pacman", "tar", "unzip", "zip",
    ]

    private static func startsWithCommandVerb(_ line: String) -> Bool {
        let firstWord = line.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        return commandVerbs.contains(firstWord)
    }

    private static func joinBackslashContinuations(_ lines: [String]) -> [String] {
        var result: [String] = []
        var current = ""
        for line in lines {
            if current.hasSuffix(" \\") || current == "\\" {
                current = String(current.dropLast()).trimmingCharacters(in: .whitespaces)
                current += " " + line.trimmingCharacters(in: .whitespaces)
            } else if !current.isEmpty {
                result.append(current)
                current = line
            } else {
                current = line
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    // MARK: - Utility

    private static func leadingWhitespaceCount(_ s: String) -> Int {
        return s.prefix(while: { $0 == " " || $0 == "\t" }).count
    }

    private static func stripCommonIndent(_ lines: [String]) -> String {
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !nonEmpty.isEmpty else { return "" }
        let minIndent = nonEmpty.map { leadingWhitespaceCount($0) }.min() ?? 0
        return lines
            .map { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return "" }
                return String(line.dropFirst(min(minIndent, line.count)))
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func splitIntoParagraphs(_ lines: [String]) -> [[String]] {
        var paragraphs: [[String]] = []
        var current: [String] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !current.isEmpty {
                    paragraphs.append(current)
                    current = []
                }
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { paragraphs.append(current) }
        return paragraphs
    }
}
