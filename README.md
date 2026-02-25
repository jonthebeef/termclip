# Termclip

Auto-clean clipboard text copied from terminal apps on macOS.

When you copy text from terminal emulators, it often comes with unwanted line breaks, leading whitespace, and formatting artifacts — especially from tools that wrap output to the terminal width. Termclip runs as a lightweight background daemon, watches your clipboard, and silently fixes the text so it pastes correctly.

## The Problem

Copy a command from your terminal and paste it somewhere:

```
scp user@host:/some/really/long/path/to/a/
file.txt ./local/destination/that/
also/wraps/badly/
```

Termclip turns that into:

```
scp user@host:/some/really/long/path/to/a/file.txt ./local/destination/that/also/wraps/badly/
```

It handles single-line commands, multi-paragraph text, code blocks with indentation, markdown, backslash continuations, and more — using heuristics that understand what kind of content you copied.

## Install

### Build from source

Requires Swift 6.0+ and macOS 13+.

```bash
git clone https://github.com/jonthebeef/termclip.git
cd termclip
swift build -c release
cp .build/release/termclip ~/.local/bin/
```

If macOS blocks the binary:

```bash
xattr -cr ~/.local/bin/termclip
codesign -fs - ~/.local/bin/termclip
```

Make sure `~/.local/bin` is on your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

```
termclip <command>

Commands:
  start                Start the background daemon
  stop                 Stop the running daemon
  status               Show current status
  notifications on|off Toggle macOS notifications
  log                  Show recent cleaning activity
  enable               Enable auto-start on login
  disable              Disable auto-start on login
  version              Show version
  help                 Show this help
```

### Quick start

```bash
termclip start
```

That's it. Termclip is now watching your clipboard. Copy text from any supported terminal app, paste it anywhere — the formatting artifacts are gone.

### Check status

```bash
termclip status
```

```
Termclip status:
  Running:       yes
  PID:           42105
  Notifications: off
  Auto-start:    disabled
```

### Auto-start on login

```bash
termclip enable
```

This installs a launchd agent so Termclip starts automatically when you log in. Remove it with `termclip disable`.

### See what it's doing

```bash
termclip log
```

Shows the last 20 cleaning events with timestamps, source app, and before/after line counts.

## How It Works

Termclip polls the system clipboard every 300ms. When it detects a change from a terminal app, it runs the text through a heuristic cleaning engine:

1. **Single line** — just trim whitespace
2. **Markdown** — preserve structure, strip common indentation
3. **Fenced code blocks** — preserve as-is
4. **Backslash continuations** — join `\`-continued lines
5. **Multiple paragraphs** — clean each paragraph independently
6. **Code with varying indentation** — preserve structure, strip common indent
7. **Shell commands** — keep as separate lines
8. **Default** — join into a single line, collapse whitespace

The engine is conservative: it preserves structure when it detects code or markdown, and only joins lines into prose when it's confident the line breaks are artifacts.

## Supported Terminals

Termclip watches these apps by default:

- Terminal.app
- iTerm2
- Warp
- VS Code
- kitty
- Alacritty
- WezTerm
- Hyper
- Zed
- Cursor
- Ghostty

The terminal list is stored in `~/.termclip/config.json` and can be edited to add or remove apps.

## Configuration

Config lives at `~/.termclip/config.json`:

```json
{
  "notificationsEnabled": false,
  "terminalBundleIDs": [
    "com.apple.Terminal",
    "com.googlecode.iterm2",
    "dev.warp.Warp-Stable",
    "com.microsoft.VSCode",
    "net.kovidgoyal.kitty",
    "io.alacritty",
    "com.github.wez.wezterm",
    "co.zeit.hyper",
    "dev.zed.Zed",
    "com.todesktop.230313mzl4w4u92",
    "com.mitchellh.ghostty"
  ]
}
```

To find the bundle ID of an app:

```bash
osascript -e 'id of app "AppName"'
```

## License

MIT
