#!/bin/bash

# 1. Open the Xcode project
echo "Opening SwiftPrep project in Xcode..."
open -a "Xcode-beta" "Untitled Project.xcodeproj"

# 2. Wait for Xcode process to appear
echo "Waiting for Xcode process to start..."
for i in {1..25}; do
    if ps aux | grep -v grep | grep -q "/Applications/Xcode-beta.app/Contents/MacOS/Xcode"; then
        echo "Xcode process detected."
        break
    fi
    sleep 1
done

# Extra wait for UI layout loading and event loop initialization
echo "Waiting 6 seconds for Xcode UI and AppleEvents server to load..."
sleep 6

# 3. Bring Xcode to the front, clean the project (Cmd + Shift + K), and run (Cmd + R)
echo "Triggering Clean Build Folder (Cmd + Shift + K)..."
osascript -e 'tell application "Xcode" to activate' \
          -e 'delay 1.5' \
          -e 'tell application "System Events" to keystroke "k" using {command down, shift down}' \
          -e 'delay 2.5' \
          -e 'tell application "System Events" to keystroke "r" using command down'

echo "========================================="
echo "🚀 Cleaned and built SwiftPrep app in Xcode!"
echo "========================================="
