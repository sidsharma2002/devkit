# DevKit POC — Setup

## Prerequisites

- macOS 12 or later
- Xcode Command Line Tools: `xcode-select --install`
- Claude Code CLI installed and authenticated: https://claude.ai/download

`install.sh` will fail with a clear error if either is missing.

## Install (one command)

```bash
cd devkit-poc && bash install.sh
```

Compiles the app, installs to `~/Applications/DevKit.app`, registers a LaunchAgent so it starts automatically on login.
The claude binary path and your shell PATH are captured at install time and injected into the LaunchAgent — no manual config needed.

## Grant Accessibility Permission (required after every install)

macOS revokes Accessibility permission whenever the binary is recompiled. Do this after every `install.sh` run:

1. System Settings > Privacy & Security > Accessibility
2. If DevKit is in the list — toggle it OFF then ON
3. If DevKit is not in the list — click `+`
   - File picker opens
   - Press `Cmd+Shift+G`
   - Type `~/Applications/` and press Enter
   - Select `DevKit.app`
4. Toggle it ON

Verify it worked:
```bash
tail -f /tmp/devkit.log
# Should show: [DevKit] Keystroke monitor active.
```

## Logs

```bash
# Live logs
tail -f /tmp/devkit.log

# One-time check
cat /tmp/devkit.log
```

Expected on healthy startup:
```
[DevKit] App launched.
[DevKit] Keystroke monitor active.
```

If you see `Accessibility not granted — waiting` → repeat the permission step above.

## Usage

### Mode 1 — ::format trigger

Type in any text field (Lark, Terminal, Notes, browser):
```
::format payment service is down prod affected users cant checkout
```
Press `Tab` → tone picker appears.

### Mode 2 — Global hotkey (POP)

1. Type your messy text anywhere
2. Select it (`Cmd+A` or `Shift+arrows`)
3. Press `Cmd+Shift+\`
4. Tone picker appears

### Tone picker controls

| Key | Action |
|-----|--------|
| `↑` `↓` | Navigate tones |
| `Return` | Confirm — replaces text |
| `Esc` | Cancel — no change |

## Restart / Reinstall

```bash
# Full reinstall (recompile + re-register LaunchAgent)
bash install.sh
# Then re-grant Accessibility (see above)

# Restart without recompiling
pkill -x DevKit && open ~/Applications/DevKit.app

# Check if running
pgrep -x DevKit

# Check LaunchAgent status
launchctl list com.yourteam.devkit
```

## File reference

| File | Role |
|------|------|
| `main.swift` | NSApplication entry, disables stdout buffering |
| `AppDelegate.swift` | Startup, Accessibility permission request + polling |
| `KeystrokeMonitor.swift` | CGEventTap — detects `::format` + Tab and `Cmd+Shift+\` |
| `TonePickerPanel.swift` | Floating NSPanel, keyboard-navigable tone list, two modes |
| `TextReplacer.swift` | Clipboard inject — Cmd+A+V (format mode) or Cmd+V (POP mode) |
| `PopHandler.swift` | Copies selection via Cmd+C, reads clipboard, triggers POP picker |
| `AIStub.swift` | Claude CLI subprocess runner — per-tone prompts, async |
| `install.sh` | Compile + bundle + sign + LaunchAgent registration |
