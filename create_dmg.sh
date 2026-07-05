#!/bin/bash
set -euo pipefail

# ==============================================================================
# SwiftForge — Production Build, Code Signing, Notarization & Stapling Pipeline
# Modeled on AnalyticsMacAgent build_pkg.sh production pipeline
# ==============================================================================

echo "===================================================="
echo "💿 Starting SwiftForge Production DMG Build, Sign & Notarize"
echo "===================================================="

# Load environment configuration from .env if present
if [ -f ".env" ]; then
    echo "📄 Loading environment configuration from .env..."
    export $(grep -v '^#' .env | xargs)
fi

# 0. Auto-detect Developer Directory
if [ -d "/Applications/Xcode-beta.app" ]; then
    export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
elif [ -d "/Applications/Xcode.app" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi
echo "ℹ️  Using Xcode at: ${DEVELOPER_DIR:-$(xcode-select -p)}"

BUILD_DIR="./build"
DERIVED_DATA="./build/DerivedData"
STAGING_DIR="./build/DMG_Staging"
DMG_OUTPUT="./SwiftForge.dmg"

# Helper: Staple with adaptive backoff retries for CloudKit CDN propagation
staple_with_backoff() {
    local target_path="$1"
    local -a delays=(15 30 45 60 90)
    local total_attempts=${#delays[@]}
    local attempt
    local delay

    for ((attempt=1; attempt<=total_attempts; attempt++)); do
        echo "📌 Staple attempt $attempt/$total_attempts for $(basename "$target_path")..."
        if xcrun stapler staple "$target_path" 2>&1; then
            echo "✅ Stapled successfully (attempt $attempt/$total_attempts)"
            return 0
        fi

        if [ $attempt -lt $total_attempts ]; then
            delay=${delays[$((attempt-1))]}
            echo "⚠️  Staple attempt $attempt failed — waiting ${delay}s for CloudKit CDN propagation..."
            sleep "$delay"
        fi
    done

    echo "⚠️  Stapling pending after $total_attempts attempts"
    return 1
}

# 1. Clean staging & previous DMG
echo "🧹 Cleaning build workspace..."
rm -rf "${STAGING_DIR}" "${DMG_OUTPUT}"
mkdir -p "${STAGING_DIR}"

# 2. Build Release .app Bundle
echo "📦 Compiling Release SwiftForge.app..."
xcodebuild -project SwiftForge.xcodeproj \
    -scheme SwiftForge \
    -configuration Release \
    -derivedDataPath "${DERIVED_DATA}" \
    build 2>&1 | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)"

APP_PATH="${DERIVED_DATA}/Build/Products/Release/SwiftForge.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "❌ Error: SwiftForge.app not found at ${APP_PATH}"
    exit 1
fi

# 3. Code Sign the .app Bundle (Inside-out signing, Hardened Runtime)
echo "🔑 Detecting Code Signing Identity..."
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 | cut -d '"' -f 2 || true)

if [ -z "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -n 1 | cut -d '"' -f 2 || true)
fi

if [ -n "$SIGNING_IDENTITY" ]; then
    echo "✍️  Signing SwiftForge.app with Identity: '$SIGNING_IDENTITY'..."
    # Sign nested frameworks / plug-ins first if any exist
    find "${APP_PATH}" -depth -type d \( -name "*.framework" -o -name "*.appex" -o -name "*.xpc" \) | while read -r bundle; do
        codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$bundle"
    done
    # Sign main app bundle LAST (seals everything inside)
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "${APP_PATH}"
else
    echo "⚠️  No Developer ID certificate found. Signing with Ad-hoc Hardened Runtime..."
    codesign --force --options runtime --deep --sign - "${APP_PATH}"
fi

# Verify signature
echo "🔍 Verifying .app signature..."
codesign --verify --deep --strict "${APP_PATH}" && echo "✅ .app signature verified!"

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

# 7. Notarize DMG with Apple Notary Service & Staple Ticket
if [ -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ] && [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
    echo "🔏 Submitting SwiftForge.dmg to Apple Notarization Service..."
    xcrun notarytool submit "${DMG_OUTPUT}" \
        --apple-id "${APPLE_ID}" \
        --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
        --team-id "${APPLE_TEAM_ID}" \
        --wait

    echo "📌 Stapling Notarization Ticket to SwiftForge.dmg..."
    staple_with_backoff "${DMG_OUTPUT}" "dmg" || true
    
    echo "🔍 Validating Notarization Ticket..."
    xcrun stapler validate "${DMG_OUTPUT}" 2>&1 && echo "✅ Staple validation: PASSED"

    xattr -rd com.apple.quarantine "${DMG_OUTPUT}" 2>/dev/null || true
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

echo "===================================================="
echo "✅ SwiftForge DMG Packaging Pipeline Complete!"
echo "===================================================="
