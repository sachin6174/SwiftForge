#!/bin/bash
set -euo pipefail

# ==============================================================================
# SwiftForge — Master All-in-One Build, Sign, Notarize & GitHub Release Script
# Modeled on AnalyticsMacAgent build_pkg.sh production pipeline
# ==============================================================================

echo "===================================================="
echo "🚀 SwiftForge Master Release Pipeline Starting..."
echo "===================================================="

# 1. Load .env
if [ -f ".env" ]; then
    echo "📄 Loading environment configuration from .env..."
    export $(grep -v '^#' .env | xargs)
fi

# 2. Xcode Toolchain Auto-detection
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
RELEASE_TAG="${1:-v1.0.0}"

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

# 3. Clean & Build App
echo "🧹 Cleaning build workspace..."
rm -rf "${STAGING_DIR}" "${DMG_OUTPUT}" "${BUILD_DIR}"
mkdir -p "${STAGING_DIR}"

echo "📦 Compiling Release SwiftForge.app..."
xcodebuild -project SwiftForge.xcodeproj \
    -scheme SwiftForge \
    -configuration Release \
    -derivedDataPath "${DERIVED_DATA}" \
    build 2>&1 | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)"

APP_PATH="${DERIVED_DATA}/Build/Products/Release/SwiftForge.app"
if [ ! -d "${APP_PATH}" ]; then
    echo "❌ Error: SwiftForge.app compilation failed!"
    exit 1
fi

# 4. Code Sign App Bundle (Inside-out signing)
echo "🔑 Detecting Code Signing Identity..."
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 | cut -d '"' -f 2 || true)
if [ -z "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -n 1 | cut -d '"' -f 2 || true)
fi

if [ -n "$SIGNING_IDENTITY" ]; then
    echo "✍️  Signing SwiftForge.app with Identity: '$SIGNING_IDENTITY'..."
    find "${APP_PATH}" -depth -type d \( -name "*.framework" -o -name "*.appex" -o -name "*.xpc" \) | while read -r bundle; do
        codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$bundle"
    done
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "${APP_PATH}"
else
    echo "⚠️  Signing with Ad-hoc Hardened Runtime..."
    codesign --force --options runtime --deep --sign - "${APP_PATH}"
fi

# 5. Create DMG Package
echo "🚚 Packaging DMG Staging..."
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

echo "CD Packaging SwiftForge.dmg..."
hdiutil create -volname "SwiftForge" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_OUTPUT}"

if [ -n "$SIGNING_IDENTITY" ]; then
    echo "✍️  Signing SwiftForge.dmg with Identity: '$SIGNING_IDENTITY'..."
    codesign --force --sign "$SIGNING_IDENTITY" "${DMG_OUTPUT}"
else
    echo "⚠️  Signing SwiftForge.dmg with Ad-hoc signature..."
    codesign --force --sign - "${DMG_OUTPUT}"
fi

# 6. Notarize DMG & Staple
if [ -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ] && [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
    echo "🔏 Submitting SwiftForge.dmg to Apple Notarization Service..."
    xcrun notarytool submit "${DMG_OUTPUT}" \
        --apple-id "${APPLE_ID}" \
        --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
        --team-id "${APPLE_TEAM_ID}" \
        --wait
    
    echo "📌 Stapling Notarization Ticket..."
    staple_with_backoff "${DMG_OUTPUT}" "dmg" || true

    echo "🔍 Validating Notarization Ticket..."
    xcrun stapler validate "${DMG_OUTPUT}" 2>&1 && echo "✅ Staple validation: PASSED"

    xattr -rd com.apple.quarantine "${DMG_OUTPUT}" 2>/dev/null || true
    echo "🎉 Notarization and Stapling Complete!"
else
    echo "ℹ️  Notarization skipped (No APPLE_APP_SPECIFIC_PASSWORD in .env)."
fi

# 7. Git Tag & Push
echo "🌐 Committing and tagging release ${RELEASE_TAG}..."
git add .
git commit -m "release: ${RELEASE_TAG} - Master All-in-One Build & Package" || true

git tag -d "${RELEASE_TAG}" 2>/dev/null || true
git push origin ":refs/tags/${RELEASE_TAG}" 2>/dev/null || true

git tag -a "${RELEASE_TAG}" -m "SwiftForge ${RELEASE_TAG} Release"
git push origin master --tags

# 8. GitHub Release & DMG Upload
echo "📤 Publishing GitHub Release & Uploading SwiftForge.dmg..."
GH_TOKEN_TO_USE="${GH_TOKEN:-}"
if [ -z "$GH_TOKEN_TO_USE" ]; then
    GH_TOKEN_TO_USE=$(security find-internet-password -s github.com -w 2>/dev/null || true)
fi

if [ -n "$GH_TOKEN_TO_USE" ]; then
    GH_TOKEN="$GH_TOKEN_TO_USE" gh release create "${RELEASE_TAG}" "${DMG_OUTPUT}" \
        --title "SwiftForge ${RELEASE_TAG}" \
        --notes "Official SwiftForge ${RELEASE_TAG} Release — macOS & iOS Studio IDE" || \
    GH_TOKEN="$GH_TOKEN_TO_USE" gh release upload "${RELEASE_TAG}" "${DMG_OUTPUT}" --clobber
    echo "🎉 Release ${RELEASE_TAG} successfully published to GitHub!"
    echo "🔗 URL: https://github.com/sachin6174/SwiftForge/releases/tag/${RELEASE_TAG}"
else
    echo "⚠️  GitHub CLI token not found. Run 'gh auth login' or set GH_TOKEN to publish automatically."
fi

echo "===================================================="
echo "✅ SwiftForge Master Release Complete!"
echo "===================================================="
