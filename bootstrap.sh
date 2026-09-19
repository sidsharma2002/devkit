#!/bin/bash
set -e

# TODO: update REPO to your GitHub URL after pushing
REPO="${DEVKIT_REPO:-https://github.com/sidsharma2002/devkit}"
CLONE_DIR="$(mktemp -d)/devkit"

echo "Cloning DevKit..."
git clone --depth 1 "$REPO" "$CLONE_DIR"

echo "Running installer..."
bash "$CLONE_DIR/devkit-poc/install.sh"
