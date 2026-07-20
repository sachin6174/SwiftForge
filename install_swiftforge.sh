#!/bin/bash
# ==============================================================================
# SwiftForge — Install via Homebrew Tap
#
# Taps sachin6174/swiftforge and installs the swiftforge cask (a signed &
# notarized SwiftForge.app pulled straight from the latest GitHub Release).
# Safe to re-run: it upgrades in place if already installed, and does
# nothing destructive.
# ==============================================================================
set -uo pipefail

TAP_NAME="sachin6174/swiftforge"
CASK_NAME="swiftforge"
APP_NAME="SwiftForge"

say()  { echo "==> $*"; }

# ------------------------------------------------------------------------
# 1. Homebrew present?
# ------------------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed. Install it first from https://brew.sh, then re-run this script."
    exit 1
fi

# ------------------------------------------------------------------------
# 2. Tap the repo (no-op if already tapped)
# ------------------------------------------------------------------------
if brew tap | grep -qx "$TAP_NAME"; then
    say "Tap $TAP_NAME already present."
else
    say "Tapping $TAP_NAME..."
    brew tap "$TAP_NAME"
fi

# ------------------------------------------------------------------------
# 3. Install, or upgrade if already installed
# ------------------------------------------------------------------------
say "Refreshing Homebrew..."
brew update >/dev/null 2>&1 || true

if brew list --cask "$CASK_NAME" >/dev/null 2>&1; then
    INSTALLED_VERSION=$(brew list --cask --versions "$CASK_NAME" | awk '{print $2}')
    say "SwiftForge $INSTALLED_VERSION is already installed. Checking for updates..."
    if brew outdated --cask | grep -qx "$CASK_NAME"; then
        say "Upgrading SwiftForge..."
        brew upgrade --cask "$CASK_NAME"
    else
        say "Already up to date."
    fi
else
    say "Installing SwiftForge..."
    brew install --cask "$CASK_NAME"
fi

# ------------------------------------------------------------------------
# 4. Confirm & launch
# ------------------------------------------------------------------------
if [ -d "/Applications/${APP_NAME}.app" ]; then
    INSTALLED_VERSION=$(brew list --cask --versions "$CASK_NAME" | awk '{print $2}')
    say "SwiftForge $INSTALLED_VERSION installed at /Applications/${APP_NAME}.app"
    read -r -p "Launch it now? [y/N] " LAUNCH
    if [[ "$LAUNCH" =~ ^[Yy]$ ]]; then
        open "/Applications/${APP_NAME}.app"
    fi
else
    echo "Something went wrong — /Applications/${APP_NAME}.app was not found after install."
    exit 1
fi
