# DevKit

macOS productivity tools for developers — keyboard-driven, Claude-powered.

## Tools

| Tool | What it does |
|------|-------------|
| **DevKit.app** | System-wide text formatter — select messy text, pick a tone, Claude rewrites it |
| **give-mr-desc** | Auto-generates MR descriptions from git diff + commit history |

## Prerequisites

- macOS 12 or later
- Xcode Command Line Tools: `xcode-select --install`
- Claude Code CLI installed and authenticated: https://claude.ai/download

`install.sh` fails with a clear error if any prerequisite is missing.

## Install

```bash
cd devkit-poc && bash install.sh
```

Compiles DevKit.app, installs to `~/Applications/DevKit.app`, registers a LaunchAgent for auto-start on login, and installs `give-mr-desc` to your PATH.

## Grant Accessibility Permission (required after every install)

macOS revokes Accessibility permission whenever the binary is recompiled.

1. System Settings > Privacy & Security > Accessibility
2. If DevKit is listed — toggle OFF then ON
3. If not listed — click `+`, press `Cmd+Shift+G`, type `~/Applications/`, select `DevKit.app`, toggle ON

Verify:
```bash
tail -f /tmp/devkit.log
# Expected: [DevKit] Keystroke monitor active.
```

---

## DevKit.app — Text Formatter

### Mode 1 — `::format` trigger

Type in any text field (Lark, Terminal, Notes, browser):
```
::format payment service is down prod users cant checkout
```
Press `Tab` — tone picker appears.

### Mode 2 — Global hotkey

1. Type messy text anywhere
2. Select it (`Cmd+A` or `Shift+arrows`)
3. Press `Cmd+Shift+\`
4. Tone picker appears

### Tone picker controls

| Key | Action |
|-----|--------|
| `↑` `↓` | Navigate tones |
| `Return` | Confirm — replaces text |
| `Esc` | Cancel |

### Available tones

| Tone | Output |
|------|--------|
| Formal | Structured incident report |
| Diplomatic | Warm, blame-free update |
| Direct | Two sentences, no fluff |
| Management | Executive summary with impact |
| Junior-friendly | Plain English, step-by-step |

---

## give-mr-desc — MR Description Generator

Run from inside any git repo:
```bash
give-mr-desc
```

Claude reads the diff and commit history itself and prints a filled-in MR description to the terminal.

### Custom template

Create `~/.config/devkit/mr-template.md` with any structure you want:

```markdown
## Summary
[what changed]

## Motivation
[why]

## Risk
[low / medium / high — and why]
```

`give-mr-desc` picks it up automatically. Delete the file to revert to the default template.

---

## Logs

```bash
tail -f /tmp/devkit.log      # live
cat /tmp/devkit.log          # one-time
```

## Restart / Reinstall

```bash
# Full reinstall
bash install.sh

# Restart without recompiling
pkill -x DevKit && open ~/Applications/DevKit.app

# Check running
pgrep -x DevKit

# Check LaunchAgent
launchctl list com.yourteam.devkit
```

## File reference

| File | Role |
|------|------|
| `DevKit/main.swift` | NSApplication entry |
| `DevKit/AppDelegate.swift` | Startup, Accessibility permission polling |
| `DevKit/KeystrokeMonitor.swift` | CGEventTap — detects `::format` + Tab and `Cmd+Shift+\` |
| `DevKit/TonePickerPanel.swift` | Floating NSPanel, keyboard-navigable tone list |
| `DevKit/TextReplacer.swift` | Clipboard inject — Cmd+A+V or Cmd+V |
| `DevKit/PopHandler.swift` | Copies selection via Cmd+C, triggers POP picker |
| `DevKit/AIStub.swift` | Claude CLI subprocess runner — per-tone prompts, async |
| `mrkit/give-mr-desc` | MR description generator script |
| `mrkit/install.sh` | Installs give-mr-desc to PATH |
| `install.sh` | Compile + bundle + sign + LaunchAgent + mrkit install |
