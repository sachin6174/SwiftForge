#!/bin/bash
set -e

# ==============================================================================
# SwiftForge — Automated DMG Build, Code Signing & Notarization Script
# ==============================================================================

echo "===================================================="
echo "💿 Starting SwiftForge DMG Build, Sign & Notarize"
echo "===================================================="

# Load environment variables from .env if present
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

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

# 3. Code Sign the .app Bundle (Hardened Runtime)
echo "🔑 Detecting Code Signing Identity..."
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 | cut -d '"' -f 2 || true)

if [ -z "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -n 1 | cut -d '"' -f 2 || true)
fi

if [ -n "$SIGNING_IDENTITY" ]; then
    echo "✍️  Signing SwiftForge.app with Identity: '$SIGNING_IDENTITY'..."
    codesign --force --options runtime --deep --sign "$SIGNING_IDENTITY" "${APP_PATH}"
else
    echo "⚠️  No Developer ID certificate found. Signing with Ad-hoc Hardened Runtime..."
    codesign --force --options runtime --deep --sign - "${APP_PATH}"
fi

# 4. Copy .app & create /Applications symlink for Drag-and-Drop installation
echo "🚚 Preparing DMG staging environment..."
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# 5. Create UDZO compressed DMG
echo "💿 Packaging SwiftForge.dmg..."
hdiutil create -volname "SwiftForge" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_OUTPUT}"

# 6. Code Sign the .dmg File
if [ -n "$SIGNING_IDENTITY" ]; then
    echo "✍️  Signing SwiftForge.dmg with Identity: '$SIGNING_IDENTITY'..."
    codesign --force --sign "$SIGNING_IDENTITY" "${DMG_OUTPUT}"
else
    echo "⚠️  Signing SwiftForge.dmg with Ad-hoc signature..."
    codesign --force --sign - "${DMG_OUTPUT}"
fi

# 7. Notarize DMG with Apple Notary Service
if [ -n "$APPLE_APP_SPECIFIC_PASSWORD" ] && [ -n "$APPLE_ID" ] && [ -n "$APPLE_TEAM_ID" ]; then
    echo "🔏 Submitting SwiftForge.dmg to Apple Notarization Service..."
    xcrun notarytool submit "${DMG_OUTPUT}" \
        --apple-id "${APPLE_ID}" \
        --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
        --team-id "${APPLE_TEAM_ID}" \
        --wait
    
    echo "📌 Stapling Notarization Ticket to SwiftForge.dmg..."
    xcrun stapler staple "${DMG_OUTPUT}"
    echo "🎉 Notarization and Stapling Complete!"
else
    echo "===================================================="
    echo "ℹ️  DMG Created & Signed locally!"
    echo "📍 File Location: $(pwd)/SwiftForge.dmg"
    echo "----------------------------------------------------"
    echo "⚠️  To enable Apple Notarization for Web Distribution:"
    echo "   1. Create an App-Specific Password at https://appleid.apple.com"
    echo "   2. Add APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx to your .env file"
    echo "   3. Re-run ./create_dmg.sh"
    echo "===================================================="
fi
