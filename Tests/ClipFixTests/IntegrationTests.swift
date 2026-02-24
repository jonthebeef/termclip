import Testing
import Foundation
@testable import clipfix

struct IntegrationTests {

    // Real-world Claude Code output examples
    @Test func claudeCodeSCPCommand() {
        let input = """
          scp -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 ~/.claude/settings.json ~/.claude/statusline-command.sh
          jongrant@jons-mac-mini-2.local:~/.claude/
        """
        let result = ClipFixCleaner.clean(input)
        #expect(!result.contains("\n"))
        #expect(result.hasPrefix("scp"))
        #expect(result.hasSuffix("~/.claude/"))
    }

    @Test func claudeCodeDockerCommand() {
        let input = """
          docker run --rm -it \\
            -v $(pwd):/app \\
            -w /app \\
            -p 3000:3000 \\
            node:18 npm start
        """
        let result = ClipFixCleaner.clean(input)
        #expect(!result.contains("\\"))
        #expect(result.hasPrefix("docker"))
    }

    @Test func claudeCodeMarkdownOutput() {
        let input = """
          ## Installation

          1. Clone the repo
          2. Run `swift build`
          3. Copy binary to PATH

          ```bash
          swift build -c release
          cp .build/release/clipfix /usr/local/bin/
          ```
        """
        let result = ClipFixCleaner.clean(input)
        #expect(result.contains("## Installation"))
        #expect(result.contains("1. Clone the repo"))
        #expect(result.contains("```bash"))
    }

    @Test func claudeCodeGitSequence() {
        let input = """
          git add .
          git commit -m "initial commit"
          git push -u origin main
        """
        let result = ClipFixCleaner.clean(input)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0].hasPrefix("git add"))
        #expect(lines[1].hasPrefix("git commit"))
        #expect(lines[2].hasPrefix("git push"))
    }

    @Test func claudeCodePythonSnippet() {
        let input = """
          def fibonacci(n):
              if n <= 1:
                  return n
              return fibonacci(n-1) + fibonacci(n-2)
        """
        let result = ClipFixCleaner.clean(input)
        #expect(result.contains("def fibonacci(n):"))
        #expect(result.contains("    if n <= 1:"))
    }
}
