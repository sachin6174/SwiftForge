#!/bin/bash
set -e

# ==============================================================================
# SwiftForge — Automated App Store Build & Release Pipeline Script
# ==============================================================================

echo "===================================================="
echo "🚀 Starting SwiftForge App Store Release Pipeline"
echo "===================================================="

PROJECT_NAME="SwiftForge"
SCHEME_NAME="SwiftForge"
XCODEPROJ="${PROJECT_NAME}.xcodeproj"
BUILD_DIR="./build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/AppStore"
EXPORT_OPTIONS_PLIST="./ExportOptions.plist"

# 1. Clean previous build artifacts
echo "🧹 Cleaning previous build artifacts..."
rm -rf "${BUILD_DIR}"
mkdir -p "${EXPORT_PATH}"

# 2. Check for App Store credentials environment variables
if [ -z "$APP_STORE_CONNECT_API_KEY_ID" ] || [ -z "$APP_STORE_CONNECT_ISSUER_ID" ]; then
    echo "⚠️  App Store Connect API Key environment variables not found."
    echo "   Ensure APP_STORE_CONNECT_API_KEY_ID & APP_STORE_CONNECT_ISSUER_ID are set for automatic upload."
fi

# 3. Build & Archive macOS Project
echo "📦 Archiving ${PROJECT_NAME} for App Store Distribution..."
xcodebuild archive \
    -project "${XCODEPROJ}" \
    -scheme "${SCHEME_NAME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "generic/platform=macOS" \
    | xcbeautify || true

if [ ! -d "${ARCHIVE_PATH}" ]; then
    echo "❌ Error: Failed to create archive at ${ARCHIVE_PATH}"
    exit 1
fi
echo "✅ Archive created successfully at ${ARCHIVE_PATH}"

# 4. Export App Store Package (.pkg)
echo "🚚 Exporting App Store Distribution Package (.pkg)..."
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" \
    -exportPath "${EXPORT_PATH}" \
    -allowProvisioningUpdates

PKG_FILE=$(find "${EXPORT_PATH}" -name "*.pkg" | head -n 1)
if [ -f "${PKG_FILE}" ]; then
    echo "✅ App Store package generated: ${PKG_FILE}"
else
    echo "⚠️ Warning: .pkg file not found directly in export path."
fi

# 5. Upload via Fastlane if available, or print status
if command -v fastlane >/dev/null 2>&1; then
    echo "⚡️ Running Fastlane release lane..."
    fastlane mac release
else
    echo "===================================================="
    echo "🎉 Build & Export Finished Successfully!"
    echo "📦 Package Path: ${EXPORT_PATH}"
    echo "💡 To upload to App Store Connect:"
    echo "   1. Install fastlane: 'gem install fastlane' and run 'fastlane mac release'"
    echo "   2. Or upload manually via Transporter app / Xcode Organizer"
    echo "===================================================="
fi
