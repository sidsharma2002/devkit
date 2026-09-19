#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="DevKit"
BUNDLE_ID="com.yourteam.devkit"
APP_DIR="$HOME/Applications/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"
SOURCES="${SCRIPT_DIR}/DevKit"
PLIST="$HOME/Library/LaunchAgents/${BUNDLE_ID}.plist"
LOG="/tmp/devkit.log"

# Prerequisite checks
echo "Checking prerequisites..."

if ! command -v swiftc &> /dev/null; then
  echo ""
  echo "Error: swiftc not found. Install Xcode Command Line Tools:"
  echo "  xcode-select --install"
  exit 1
fi

CLAUDE_PATH=$(command -v claude 2>/dev/null || true)
if [ -z "$CLAUDE_PATH" ]; then
  echo ""
  echo "Error: claude CLI not found. Install Claude Code from:"
  echo "  https://claude.ai/download"
  echo "Then run this script again."
  exit 1
fi
echo "  swiftc: $(swiftc --version 2>&1 | head -1)"
echo "  claude: $CLAUDE_PATH"

# Unload LaunchAgent if registered (handles reinstall cleanly)
if launchctl list | grep -q "$BUNDLE_ID" 2>/dev/null; then
  echo "Unloading LaunchAgent..."
  launchctl unload "$PLIST" 2>/dev/null || true
fi

# Kill any running instance
if pgrep -x "$APP_NAME" > /dev/null 2>&1; then
  echo "Stopping running ${APP_NAME}..."
  pkill -x "$APP_NAME" || true
  sleep 0.5
fi

echo "Building ${APP_NAME}..."
mkdir -p "$MACOS" "${CONTENTS}/Resources"

swiftc \
  "${SOURCES}/main.swift" \
  "${SOURCES}/AppDelegate.swift" \
  "${SOURCES}/KeystrokeMonitor.swift" \
  "${SOURCES}/TonePickerPanel.swift" \
  "${SOURCES}/TextReplacer.swift" \
  "${SOURCES}/AIStub.swift" \
  "${SOURCES}/PopHandler.swift" \
  -o "${MACOS}/${APP_NAME}" \
  -framework Cocoa \
  -framework Carbon

cp "${SOURCES}/Info.plist" "${CONTENTS}/Info.plist"

# Ad-hoc sign — required for Accessibility API to work
codesign --force --deep --sign - "$APP_DIR"

echo "Installed to ${APP_DIR}"

# Write LaunchAgent plist
# Inject claude path + current shell PATH so app works without user's shell env
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${BUNDLE_ID}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${MACOS}/${APP_NAME}</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>DEVKIT_CLAUDE_PATH</key>
        <string>${CLAUDE_PATH}</string>
        <key>PATH</key>
        <string>${PATH}</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOG}</string>
    <key>StandardErrorPath</key>
    <string>${LOG}</string>
</dict>
</plist>
EOF

# Load and start
launchctl load "$PLIST"

echo ""
echo "LaunchAgent registered — DevKit starts automatically on login."
echo "Logs: tail -f ${LOG}"
echo ""
echo "On first run: grant Accessibility in"
echo "System Settings > Privacy & Security > Accessibility > DevKit"
echo ""
echo "In any text field type:"
echo "  ::format payment service is down prod affected"
echo "and press Tab"
