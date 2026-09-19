#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing give-mr-desc..."

# Check claude CLI
CLAUDE_PATH=$(command -v claude 2>/dev/null || true)
if [ -z "$CLAUDE_PATH" ]; then
  echo ""
  echo "Error: claude CLI not found. Install from:"
  echo "  https://claude.ai/download"
  exit 1
fi
echo "  claude: $CLAUDE_PATH"

# Determine install directory
if [ -w "/usr/local/bin" ]; then
  INSTALL_DIR="/usr/local/bin"
elif [ -d "$HOME/.local/bin" ]; then
  INSTALL_DIR="$HOME/.local/bin"
else
  mkdir -p "$HOME/.local/bin"
  INSTALL_DIR="$HOME/.local/bin"
fi

# Install
cp "$SCRIPT_DIR/give-mr-desc" "$INSTALL_DIR/give-mr-desc"
chmod +x "$INSTALL_DIR/give-mr-desc"

echo "  installed: $INSTALL_DIR/give-mr-desc"

# PATH check
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  echo ""
  echo "  Warning: $INSTALL_DIR is not in your PATH."
  echo "  Add this to your ~/.zshrc or ~/.bash_profile:"
  echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo ""
echo "Done. Run from inside any git repo:"
echo "  give-mr-desc"
