#!/bin/bash
set -e

echo "===================================================="
echo "🚀 Opening SwiftForge project in Xcode..."
echo "===================================================="

XCODEPROJ="SwiftForge.xcodeproj"

if [ -d "/Applications/Xcode-beta.app" ]; then
    open -a "/Applications/Xcode-beta.app" "$XCODEPROJ"
elif [ -d "/Applications/Xcode.app" ]; then
    open -a "/Applications/Xcode.app" "$XCODEPROJ"
else
    open "$XCODEPROJ"
fi

echo "✅ Opened SwiftForge in Xcode."
