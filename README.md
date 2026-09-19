# DevKit

**AI writing tools built for developers. Keyboard-only. Zero context switching.**

You write fast, messy, and technical. DevKit rewrites it — into a polished message, a clear incident update, or a full MR description — without you ever leaving the keyboard.

---

## The Problem

You spend more time than you should on:

- Rewriting a messy Slack/Lark message so it doesn't sound alarming
- Translating a stack trace into something a PM can understand
- Filling out an MR description from scratch after already writing the code

These aren't hard problems. They're just friction. DevKit removes them.

---

## What's Inside

### DevKit.app — System-wide Text Formatter

Select any text. Press a hotkey. Pick a tone. Claude rewrites it inline.

Works in **any app** — Lark, Terminal, Notes, browser, IDE.

**Before:**
```
hey so payment service is down again prod is affected users cant checkout looked at logs nothing obvious yet
```

**After (Formal):**
```
Incident Report | Severity: P0

- Summary: Payment service is currently unavailable in production
- Impact: Users unable to complete checkout
- Status: Under investigation — no root cause identified yet
- Action Required: Payments team to review service logs
```

**After (Direct):**
```
Payment service is down in prod. Payments team — investigate logs immediately.
```

**After (Diplomatic):**
```
Hey team, just a heads up — we're seeing some instability with the payment service in production.
Users are hitting checkout issues. Would appreciate a look from the payments side when you can.
```

Five tones built-in. All keyboard navigable. No mouse.

---

### give-mr-desc — MR Description Generator

Run one command after `git push`. Claude reads your diff and commit history and writes the MR description for you.

```bash
give-mr-desc
```

```markdown
## What
Adds retry logic to the payment processor with exponential backoff, capped at 3 attempts.

## Why
Transient network failures were causing hard failures on the first attempt, leading to
unnecessary checkout errors under intermittent connectivity.

## Changes
- Add `RetryHandler` with configurable attempt count and backoff multiplier
- Wrap `PaymentProcessor.charge()` calls with retry logic
- Add unit tests for retry behaviour under simulated failure

## Testing
Run `./gradlew :payments:test` — all existing tests pass, 6 new tests added.
```

No template to fill. No copy-pasting commit messages. Just ship.

---

## Install

**One command:**

```bash
curl -fsSL https://raw.githubusercontent.com/sidsharma2002/devkit/main/devkit-poc/bootstrap.sh | bash
```

Installs DevKit.app and `give-mr-desc` in one shot.

**Just the MR generator (no Xcode needed):**

```bash
curl -fsSL https://raw.githubusercontent.com/sidsharma2002/devkit/main/devkit-poc/mrkit/give-mr-desc \
  -o ~/.local/bin/give-mr-desc && chmod +x ~/.local/bin/give-mr-desc
```

---

## Requirements

- macOS 12+
- [Claude Code CLI](https://claude.ai/download) — authenticated
- Xcode Command Line Tools (`xcode-select --install`) — only for DevKit.app

---

## Usage

### Text Formatter — Two Ways to Trigger

**Inline trigger** — type in any text field and press `Tab`:
```
::format <your messy text here>
```

**Hotkey** — select any existing text, press `Cmd+Shift+\`

### Tone Picker

| Key | Action |
|-----|--------|
| `↑` `↓` | Navigate |
| `Return` | Rewrite + paste |
| `Esc` | Cancel |

### Available Tones

| Tone | Best for |
|------|----------|
| Formal | Incident reports, status updates |
| Diplomatic | Feedback, blame-free updates |
| Direct | Engineering pings, on-call alerts |
| Management | Executive summaries, stakeholder updates |
| Junior-friendly | Onboarding help, explaining outages |

### MR Description Generator

```bash
# From inside any git repo
give-mr-desc
```

Custom template? Create `~/.config/devkit/mr-template.md` with your own structure — DevKit picks it up automatically.

---

## After Install — Grant Accessibility (DevKit.app only)

macOS requires Accessibility permission for DevKit to intercept keystrokes.

1. System Settings > Privacy & Security > Accessibility
2. Find DevKit — toggle OFF then ON (or add via `+` if not listed)

Verify:
```bash
tail -f /tmp/devkit.log
# [DevKit] Keystroke monitor active.
```

---

## Troubleshooting

```bash
# Live logs
tail -f /tmp/devkit.log

# Is DevKit running?
pgrep -x DevKit

# Restart without reinstalling
pkill -x DevKit && open ~/Applications/DevKit.app

# Full reinstall
bash devkit-poc/install.sh
```

---

## File Reference

| File | Role |
|------|------|
| `DevKit/KeystrokeMonitor.swift` | CGEventTap — detects triggers and hotkey |
| `DevKit/TonePickerPanel.swift` | Floating picker panel, keyboard nav |
| `DevKit/TextReplacer.swift` | Clipboard inject and paste |
| `DevKit/AIStub.swift` | Claude CLI subprocess runner |
| `mrkit/give-mr-desc` | MR description generator |
| `install.sh` | Compile + bundle + LaunchAgent + mrkit |
| `bootstrap.sh` | One-liner remote install |
