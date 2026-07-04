#!/bin/bash
set -e

# ==============================================================================
# SwiftForge — Automated DMG Disk Image Creation Script
# ==============================================================================

echo "===================================================="
echo "💿 Generating SwiftForge macOS DMG Disk Image..."
echo "===================================================="

# 0. Auto-detect Developer Directory
if [ -d "/Applications/Xcode-beta.app" ]; then
    export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
elif [ -d "/Applications/Xcode.app" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

BUILD_DIR="./build"
DERIVED_DATA="./build/DerivedData"
STAGING_DIR="./build/DMG_Staging"
DMG_OUTPUT="./SwiftForge.dmg"

# 1. Clean staging & previous DMG
rm -rf "${STAGING_DIR}" "${DMG_OUTPUT}"
mkdir -p "${STAGING_DIR}"

# 2. Build Release .app Bundle
echo "📦 Building Release SwiftForge.app..."
xcodebuild -project SwiftForge.xcodeproj \
    -scheme SwiftForge \
    -configuration Release \
    -derivedDataPath "${DERIVED_DATA}" \
    build

APP_PATH="${DERIVED_DATA}/Build/Products/Release/SwiftForge.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "❌ Error: SwiftForge.app not found at ${APP_PATH}"
    exit 1
fi

# 3. Copy .app & create /Applications symlink for Drag-and-Drop installation
echo "🚚 Preparing DMG staging environment..."
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# 4. Create UDZO compressed DMG
echo "💿 Packaging SwiftForge.dmg..."
hdiutil create -volname "SwiftForge" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_OUTPUT}"

echo "===================================================="
echo "✅ SwiftForge.dmg successfully created!"
echo "📍 Location: $(pwd)/SwiftForge.dmg"
echo "===================================================="
