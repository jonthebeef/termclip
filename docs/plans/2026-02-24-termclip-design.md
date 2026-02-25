# Termclip Design Document

## Problem

Copying text from terminal apps (Terminal.app, iTerm2, Warp, VS Code terminal, etc.) produces mangled output: leading whitespace, unwanted line breaks from word wrapping, and terminal-width padding. This is especially painful when copying commands from CLI tools like Claude Code.

No existing macOS app solves this. Current clipboard tools (CleanBoard, PastePlain) strip rich text formatting — a completely different problem.

## Solution

Termclip is a lightweight, invisible macOS daemon that monitors the clipboard and automatically cleans text copied from terminal apps. It uses heuristics to intelligently decide what to clean and what to preserve.

## Architecture

### Single Binary, Two Modes

One compiled Swift binary (`termclip`) operates as both the daemon and the CLI.

- **Daemon mode**: `termclip start` forks into the background, monitors pasteboard via `NSPasteboard.changeCount`, detects frontmost app via `NSWorkspace`, applies cleaning heuristics, writes cleaned text back to the pasteboard.
- **CLI mode**: All other subcommands (`stop`, `status`, `notifications`, `log`, `enable`, `disable`) communicate with the running daemon via PID file and signals, or read/write shared config.

### File Locations

```
~/.termclip/
  termclip.pid        # PID of running daemon
  config.json        # User preferences
  termclip.log        # Recent cleaning activity (rolling, capped)
```

### Launchd Integration

- `termclip enable` installs a launchd plist at `~/Library/LaunchAgents/com.termclip.agent.plist` for auto-start on login
- `termclip disable` removes it
- Not installed by default — user opts in

## CLI Interface

```
termclip start                # Start daemon in background
termclip stop                 # Stop running daemon
termclip status               # Show running state, notification setting
termclip notifications on     # Enable macOS notifications on clean
termclip notifications off    # Disable notifications
termclip log                  # Show recent cleaning activity
termclip enable               # Install launchd agent for auto-start on login
termclip disable              # Remove launchd agent
```

## Terminal Detection

The daemon checks the frontmost application's bundle identifier against a known list of terminal apps:

- `com.apple.Terminal` (Terminal.app)
- `com.googlecode.iterm2` (iTerm2)
- `dev.warp.Warp-Stable` (Warp)
- `com.microsoft.VSCode` (VS Code)
- `net.kovidgoyal.kitty` (Kitty)
- `io.alacritty` (Alacritty)
- `com.github.wez.wezterm` (WezTerm)
- `co.zeit.hyper` (Hyper)
- `dev.zed.Zed` (Zed)
- `com.todesktop.230313mzl4w4u92` (Cursor)

This list is stored in config.json so users can add custom terminal apps.

## Smart Cleaning Heuristics

The core intelligence of Termclip. Applied only to plain text copied from terminal apps.

### Decision Flow

```
1. Is it a single line already?
   → Strip leading/trailing whitespace only. Done.

2. Does it contain markdown patterns? (headings, bullets, fenced code blocks, tables)
   → Preserve structure. Strip common leading indent. Done.

3. Does it have blank lines separating sections?
   → Preserve blank lines as paragraph breaks.
   → Within each paragraph, apply line-joining logic (steps 4-5).

4. Do lines have varying indentation? (suggests code/script)
   → Preserve structure. Strip common leading indent. Done.

5. Does each non-empty line start with a command verb? (git, cd, npm, docker, etc.)
   → Keep as separate lines. Strip leading whitespace. Done.

6. Default: lines have consistent leading whitespace, no structural markers.
   → Join into a single line. Collapse multiple spaces. Trim. Done.
```

### Heuristic Details

**Markdown detection**: Check for lines starting with `#`, `- `, `* `, `> `, fenced code blocks (```), table separators (`|---|`).

**Varying indentation**: If the standard deviation of leading whitespace lengths (ignoring blank lines) exceeds a threshold, treat as structured code.

**Command verb detection**: Check if lines start with common shell commands: `git`, `cd`, `ls`, `npm`, `yarn`, `docker`, `kubectl`, `ssh`, `scp`, `curl`, `wget`, `pip`, `brew`, `make`, `cargo`, `go`, `python`, `node`, `ruby`, etc.

**Line continuation detection**: If a line ends mid-path (`/`), mid-flag (`-`), or with a backslash (`\`), the next line is a continuation — join them.

## Notifications

When enabled, Termclip sends a macOS `UserNotification` after cleaning:

- Title: "Termclip"
- Body: Preview of cleaned text (truncated to ~60 chars)
- Disappears automatically (no action required)

Notifications are off by default. Toggle via `termclip notifications on/off`.

## Logging

Rolling log at `~/.termclip/termclip.log`, capped at 1000 entries. Each entry:

```
[2026-02-24 14:32:01] Cleaned from iTerm2: "scp -o IdentitiesOnly=ye..." (3 lines → 1)
```

Viewable via `termclip log` (shows last 20 entries by default).

## Distribution

- **Homebrew**: Primary distribution channel (`brew install termclip`)
- **Direct download**: Compiled universal binary (arm64 + x86_64) from GitHub releases
- **Source**: `swift build` for developers

## Future Considerations (not in v1)

- Custom heuristic rules via config
- AI-powered mode for ambiguous cases (premium feature)
- Keyboard shortcut to force-clean (bypass terminal detection)
- iOS/iPadOS companion via Universal Clipboard
