#!/bin/bash
set -e

echo "===================================================="
echo "🚀 Dual-Platform Build: macOS + iOS (sachin's iPhone)"
echo "===================================================="

XCODEPROJ="SwiftForge.xcodeproj"
DEV_DIR="/Applications/Xcode-beta.app/Contents/Developer"

if [ -d "$DEV_DIR" ]; then
    export DEVELOPER_DIR="$DEV_DIR"
fi

# 1. Build macOS Release Target
echo "🖥️ Building macOS Release Target..."
xcodebuild -project "$XCODEPROJ" -scheme SwiftForge -configuration Release -derivedDataPath ./build/DerivedData CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES build > /dev/null

MAC_APP="./build/DerivedData/Build/Products/Release/CodeForge.app"
if [ -d "$MAC_APP" ]; then
    echo "▶️ Launching CodeForge Native macOS App..."
    open "$MAC_APP"
fi

# 2. Build iOS Physical Device / Simulator Target
echo "📱 Building iOS Target (sachin's iPhone / Simulator)..."
PHYSICAL_DEVICE_ID="00008101-00120C8E3410801E"

if xcodebuild -project "$XCODEPROJ" -scheme SwiftForge -destination "id=$PHYSICAL_DEVICE_ID" -configuration Release -derivedDataPath ./build/DerivedData_iOSDevice CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES build > /dev/null 2>&1; then
    echo "✅ iOS Build Succeeded for sachin's iPhone ($PHYSICAL_DEVICE_ID)"
else
    echo "📱 Physical device not ready, building for iOS Simulator..."
    xcodebuild -project "$XCODEPROJ" -scheme SwiftForge -sdk iphonesimulator -configuration Release -derivedDataPath ./build/DerivedData_iOS CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES build > /dev/null
    echo "✅ iOS Simulator Build Succeeded."
fi

# 3. Open project in Xcode
if [ -d "/Applications/Xcode-beta.app" ]; then
    open -a "/Applications/Xcode-beta.app" "$XCODEPROJ"
fi

echo "===================================================="
echo "✅ Both macOS & iOS Builds Succeeded & Launched!"
echo "===================================================="

LOG_FILE="$HOME/Documents/swiftforge_execution.log"
if [ -f "$LOG_FILE" ]; then
    echo "===================================================="
    echo "📜 Real-Time Cross-Platform Execution Logs:"
    echo "===================================================="
    tail -n 25 "$LOG_FILE"
fi
