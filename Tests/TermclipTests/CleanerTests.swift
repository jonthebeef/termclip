import Testing
import Foundation
@testable import termclip

struct CleanerTests {

    // MARK: - Single line passthrough

    @Test func singleLineStripsWhitespace() {
        let input = "  scp foo bar  "
        let result = TermclipCleaner.clean(input)
        #expect(result == "scp foo bar")
    }

    @Test func alreadyCleanSingleLine() {
        let input = "git push origin main"
        let result = TermclipCleaner.clean(input)
        #expect(result == input)
    }

    // MARK: - Wrapped command joining

    @Test func wrappedCommandJoinsToOneLine() {
        let input = """
          scp -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 ~/.claude/settings.json
          jongrant@jons-mac-mini-2.local:~/.claude/
        """
        let result = TermclipCleaner.clean(input)
        #expect(result == "scp -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 ~/.claude/settings.json jongrant@jons-mac-mini-2.local:~/.claude/")
    }

    @Test func wrappedLongCurlCommand() {
        let input = """
          curl -X POST https://api.example.com/v1/deploy
          -H "Authorization: Bearer token123"
          -d '{"app": "termclip"}'
        """
        let result = TermclipCleaner.clean(input)
        #expect(result == "curl -X POST https://api.example.com/v1/deploy -H \"Authorization: Bearer token123\" -d '{\"app\": \"termclip\"}'")
    }

    // MARK: - Backslash continuations

    @Test func backslashContinuationJoins() {
        let input = """
          docker run \\
            -v /host:/container \\
            -p 8080:80 \\
            nginx
        """
        let result = TermclipCleaner.clean(input)
        #expect(result == "docker run -v /host:/container -p 8080:80 nginx")
    }

    // MARK: - Markdown preservation

    @Test func markdownHeadingsPreserved() {
        let input = """
          ## Section Title

          Some body text here.
          - bullet one
          - bullet two
        """
        let result = TermclipCleaner.clean(input)
        #expect(result.contains("## Section Title"))
        #expect(result.contains("- bullet one"))
        #expect(result.contains("- bullet two"))
    }

    @Test func fencedCodeBlockPreserved() {
        let input = """
          ```bash
          echo "hello"
          echo "world"
          ```
        """
        let result = TermclipCleaner.clean(input)
        #expect(result.contains("```bash"))
        #expect(result.contains("echo \"hello\""))
        #expect(result.contains("echo \"world\""))
    }

    // MARK: - Code preservation (varying indent)

    @Test func codeWithVaryingIndentPreserved() {
        let input = """
          def hello():
              print("world")
              if True:
                  return 1
        """
        let result = TermclipCleaner.clean(input)
        #expect(result.contains("def hello():"))
        #expect(result.contains("    print(\"world\")"))
        #expect(result.contains("        return 1"))
    }

    // MARK: - Separate commands preserved

    @Test func separateCommandsKeptAsSeparateLines() {
        let input = """
          git add .
          git commit -m "fix"
          git push
        """
        let result = TermclipCleaner.clean(input)
        #expect(result == "git add .\ngit commit -m \"fix\"\ngit push")
    }

    // MARK: - Blank line paragraph preservation

    @Test func blankLinesSeparateParagraphs() {
        let input = """
          First paragraph that wraps
          across two lines.

          Second paragraph also
          wrapping here.
        """
        let result = TermclipCleaner.clean(input)
        #expect(result.contains("First paragraph that wraps across two lines."))
        #expect(result.contains("Second paragraph also wrapping here."))
        #expect(result.contains("\n\n"))
    }

    // MARK: - Empty / whitespace only

    @Test func emptyStringReturnsEmpty() {
        #expect(TermclipCleaner.clean("") == "")
    }

    @Test func whitespaceOnlyReturnsEmpty() {
        #expect(TermclipCleaner.clean("   \n  \n   ") == "")
    }

    // MARK: - No change needed

    @Test func cleanTextUnchanged() {
        let input = "already clean"
        #expect(TermclipCleaner.clean(input) == input)
        #expect(TermclipCleaner.isAlreadyClean(input))
    }
}
