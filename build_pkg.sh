#!/usr/bin/env bash
# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  build_pkg.sh — AnalyticsMacAgent production PKG builder                 ║
# ║                                                                          ║
# ║  Pipeline:                                                               ║
# ║    1. Preflight        → verify certs, AuthKey, pkg_scripts              ║
# ║    2. Archive          → xcodebuild archive (Release)                    ║
# ║    3. Export           → xcodebuild -exportArchive (Developer ID)        ║
# ║    4. Sign Internals   → inside-out codesign (no --deep)                 ║
# ║    5. Build PKG        → pkgbuild → productbuild → productsign           ║
# ║    6. Notarize + Staple                                                  ║
# ║    7. Auto-Install     → installer -pkg → verify → launch               ║
# ║                                                                          ║
# ║  Usage:                                                                  ║
# ║    ./build_pkg.sh              # auto-increment version                  ║
# ║    ./build_pkg.sh 5.2.0        # override version                       ║
# ║                                                                          ║
# ║  Modeled on SureMDMNixMac CI/CD pipeline (3-stage YAML)                  ║
# ╚════════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# Logging — every line is timestamped and tee'd to a persistent log file
# ══════════════════════════════════════════════════════════════════════════════
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
RELEASE_DIR="$PROJECT_DIR/release"
mkdir -p "$RELEASE_DIR"

BUILD_LOG_FILE="$RELEASE_DIR/build_pkg_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$BUILD_LOG_FILE") 2>&1

log()     { echo "[$(date '+%H:%M:%S')] $*"; }
log_ok()  { echo "[$(date '+%H:%M:%S')] ✅ $*"; }
log_warn(){ echo "[$(date '+%H:%M:%S')] ⚠️  $*"; }
log_err() { echo "[$(date '+%H:%M:%S')] ❌ $*"; }
log_step(){ echo ""; echo "[$(date '+%H:%M:%S')] ══ $* ══"; }
log_sub() { echo "[$(date '+%H:%M:%S')]    ↳ $*"; }
die()     { log_err "$*"; exit 1; }

log "Build log → $BUILD_LOG_FILE"

# ══════════════════════════════════════════════════════════════════════════════
# Config
# ══════════════════════════════════════════════════════════════════════════════
PROJECT="$PROJECT_DIR/AnalyticsMacAgent.xcodeproj"
SCHEME="AnalyticsMacAgent"
BUNDLE_ID="com.gears42.Nix-Agent.AnalyticsMacAgent"
TEAM_ID="385W379KB3"
APP_SIGN_ID="Developer ID Application: 42Gears Mobility Systems Private Limited (385W379KB3)"
PKG_SIGN_ID="Developer ID Installer: 42Gears Mobility Systems Private Limited (385W379KB3)"

ARCHIVE_PATH="$RELEASE_DIR/AnalyticsMacAgent.xcarchive"
EXPORT_DIR="$RELEASE_DIR/export"
PKG_ROOT="$RELEASE_DIR/pkgroot"
PKG_BUILD_DIR="$RELEASE_DIR/pkg_build"
PKG_SCRIPTS_SRC="$PROJECT_DIR/others/pkg_scripts"
TMP_DIR="$RELEASE_DIR/.tmp"

# Notarization API key
KEY_FILE="$PROJECT_DIR/others/AuthKey_J98MRTNKQF.p8"
KEY_ID="J98MRTNKQF"
ISSUER="69a6de7b-94e9-47e3-e053-5b8c7c11a4d1"

# ══════════════════════════════════════════════════════════════════════════════
# Read install credentials from config.json
# ══════════════════════════════════════════════════════════════════════════════
CONFIG_JSON="$(dirname "$PROJECT_DIR")/config.json"
INSTALL_USER=""
INSTALL_PASS=""
if [[ -f "$CONFIG_JSON" ]]; then
    INSTALL_USER=$(python3 -c "import json; d=json.load(open('$CONFIG_JSON')); print(d.get('userToBeUsedForOperations',''))" 2>/dev/null || echo "")
    INSTALL_PASS=$(python3 -c "import json; d=json.load(open('$CONFIG_JSON')); u=d.get('userToBeUsedForOperations',''); arr=d.get('usersArray',[]); match=[x['password'] for x in arr if x.get('username')==u]; print(match[0] if match else '')" 2>/dev/null || echo "")
    log "Config: install user='$INSTALL_USER', password=$([ -n "$INSTALL_PASS" ] && echo 'SET' || echo 'EMPTY')"
else
    log_warn "config.json not found at $CONFIG_JSON — auto-install will be skipped"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Cleanup trap — remove temp artifacts on exit (keep .pkg + logs)
# ══════════════════════════════════════════════════════════════════════════════
cleanup() {
    log "Cleaning up temp artifacts..."
    rm -rf "$TMP_DIR" 2>/dev/null || true
    rm -rf "$PKG_ROOT" 2>/dev/null || true
    rm -rf "$PKG_BUILD_DIR" 2>/dev/null || true
    rm -rf "$EXPORT_DIR" 2>/dev/null || true
    rm -f  "$RELEASE_DIR/ExportOptions.plist" 2>/dev/null || true
    rm -f  "$RELEASE_DIR/components.plist" 2>/dev/null || true
    rm -rf "$RELEASE_DIR/pkg_scripts_stage" 2>/dev/null || true
    log "Cleanup done"
}
trap cleanup EXIT

# ══════════════════════════════════════════════════════════════════════════════
# Version
# ══════════════════════════════════════════════════════════════════════════════
PBXPROJ="$PROJECT/project.pbxproj"
if [[ $# -ge 1 ]]; then
    VERSION="$1"
    sed -i '' "s/MARKETING_VERSION = [0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/MARKETING_VERSION = ${VERSION}/g" "$PBXPROJ"
    log "Version set to $VERSION (override)"
else
    CURRENT=$(grep -m1 'MARKETING_VERSION' "$PBXPROJ" | sed 's/.*= //;s/;//' | tr -d '[:space:]')
    MAJOR=$(echo "$CURRENT" | cut -d. -f1)
    MINOR=$(echo "$CURRENT" | cut -d. -f2)
    PATCH=$(echo "$CURRENT" | cut -d. -f3)
    if [[ $PATCH -lt 5 ]]; then PATCH=$((PATCH + 1))
    else
        PATCH=0
        if [[ $MINOR -lt 5 ]]; then MINOR=$((MINOR + 1))
        else MINOR=0; MAJOR=$((MAJOR + 1)); fi
    fi
    VERSION="${MAJOR}.${MINOR}.${PATCH}"
    sed -i '' "s/MARKETING_VERSION = ${CURRENT};/MARKETING_VERSION = ${VERSION};/g" "$PBXPROJ"
    log "Version bumped: $CURRENT → $VERSION"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  AnalyticsMacAgent v${VERSION} — Build Starting              ║"
echo "╚════════════════════════════════════════════════════════════╝"

# Track timing
BUILD_START=$(date +%s)

# ══════════════════════════════════════════════════════════════════════════════
# Preflight checks
# ══════════════════════════════════════════════════════════════════════════════
log_step "Step 0/7: Preflight Checks"

# ── 0a. Verify pkg_scripts ────────────────────────────────────────────────────
log "Checking pkg_scripts at $PKG_SCRIPTS_SRC..."
if [[ -f "$PKG_SCRIPTS_SRC/preinstall" && -f "$PKG_SCRIPTS_SRC/postinstall" ]]; then
    PRE_SIZE=$(wc -c < "$PKG_SCRIPTS_SRC/preinstall" | tr -d ' ')
    POST_SIZE=$(wc -c < "$PKG_SCRIPTS_SRC/postinstall" | tr -d ' ')
    log_ok "pkg_scripts found"
    log_sub "preinstall:  $PRE_SIZE bytes, $(wc -l < "$PKG_SCRIPTS_SRC/preinstall" | tr -d ' ') lines"
    log_sub "postinstall: $POST_SIZE bytes, $(wc -l < "$PKG_SCRIPTS_SRC/postinstall" | tr -d ' ') lines"

    # Validate scripts have correct shebang
    if head -1 "$PKG_SCRIPTS_SRC/preinstall" | grep -q '#!/bin/bash'; then
        log_sub "preinstall shebang: OK (#!/bin/bash)"
    else
        log_warn "preinstall shebang missing or incorrect — may fail during pkg install"
    fi
    if head -1 "$PKG_SCRIPTS_SRC/postinstall" | grep -q '#!/bin/bash'; then
        log_sub "postinstall shebang: OK (#!/bin/bash)"
    else
        log_warn "postinstall shebang missing or incorrect — may fail during pkg install"
    fi

    # Quick syntax check on pkg_scripts
    if bash -n "$PKG_SCRIPTS_SRC/preinstall" 2>/dev/null; then
        log_sub "preinstall syntax: OK"
    else
        die "preinstall has bash syntax errors — fix before building"
    fi
    if bash -n "$PKG_SCRIPTS_SRC/postinstall" 2>/dev/null; then
        log_sub "postinstall syntax: OK"
    else
        die "postinstall has bash syntax errors — fix before building"
    fi
else
    die "Missing pkg_scripts at $PKG_SCRIPTS_SRC (need preinstall + postinstall)"
fi

# ── 0b. Verify signing certificates ──────────────────────────────────────────
log "Checking signing certificates in keychain..."
if security find-identity -v -p codesigning | grep -q "$APP_SIGN_ID"; then
    log_ok "Developer ID Application certificate found"
else
    die "Developer ID Application certificate NOT found in keychain. Expected: $APP_SIGN_ID"
fi

if security find-identity -v | grep -q "Developer ID Installer"; then
    log_ok "Developer ID Installer certificate found"
else
    log_warn "Developer ID Installer certificate not found — productsign will fail"
fi

# ── 0c. Notarization key ─────────────────────────────────────────────────────
HAS_NOTARIZE=0
if [[ -f "$KEY_FILE" ]]; then
    log_ok "AuthKey found at $KEY_FILE → notarization enabled"
    log_sub "Key ID: $KEY_ID"
    log_sub "Issuer: $ISSUER"
    HAS_NOTARIZE=1
else
    log_warn "AuthKey not found at $KEY_FILE → skipping notarization"
fi

# ── 0d. Xcode version ────────────────────────────────────────────────────────
XCODE_VER=$(xcodebuild -version 2>/dev/null | head -1 || echo "unknown")
XCODE_PATH=$(xcode-select -p 2>/dev/null || echo "unknown")
log "Xcode: $XCODE_VER"
log_sub "Path: $XCODE_PATH"

# ── 0e. Disk space check ─────────────────────────────────────────────────────
AVAIL_GB=$(df -g "$PROJECT_DIR" | tail -1 | awk '{print $4}')
log "Disk space available: ${AVAIL_GB} GB"
if [[ $AVAIL_GB -lt 2 ]]; then
    log_warn "Low disk space — build may fail if < 2 GB free"
fi

# Create working directories
mkdir -p "$RELEASE_DIR" "$TMP_DIR"
log_ok "Preflight checks passed"

# ══════════════════════════════════════════════════════════════════════════════
# Helper: Staple with exponential backoff
# ══════════════════════════════════════════════════════════════════════════════
staple_with_backoff() {
    local pkg_path="$1"
    local phase="${2:-initial}"
    local -a delays

    if [[ "$phase" == "postinstall" ]]; then
        delays=(30 60 120)
    else
        delays=(45 90 180 300 600)
    fi

    local total_attempts=${#delays[@]}
    local attempt
    local delay

    for ((attempt=1; attempt<=total_attempts; attempt++)); do
        log "Staple attempt $attempt/$total_attempts..."
        if xcrun stapler staple "$pkg_path" 2>&1; then
            log_ok "Stapled successfully (attempt $attempt/$total_attempts)"
            return 0
        fi

        if [[ $attempt -lt $total_attempts ]]; then
            delay=${delays[$((attempt-1))]}
            log_warn "Staple attempt $attempt/$total_attempts failed — waiting ${delay}s..."
            sleep "$delay"
        fi
    done

    log_warn "Stapling still pending after $total_attempts attempts"
    return 1
}

# ══════════════════════════════════════════════════════════════════════════════
# Helper: Sign bundles + binaries embedded inside zip files
#
# CRITICAL: Zips may contain nested bundles (.prefPane, .app, .xpc, .framework).
# Signing bare Mach-O binaries inside a bundle BREAKS the bundle's
# _CodeSignature/CodeResources seal. We must:
#   1. Find all bundles inside the zip
#   2. Sort innermost-first (XPC → app → prefPane)
#   3. Sign each BUNDLE (not bare binary) with codesign --force
#   4. Sign any remaining standalone Mach-O files outside bundles
#   5. Re-zip using ditto (preserves macOS resource forks)
# ══════════════════════════════════════════════════════════════════════════════
sign_embedded_zip_binaries() {
    local zip_path="$1"
    local zip_name
    zip_name="$(basename "$zip_path")"
    [[ -f "$zip_path" ]] || { log_warn "$zip_name not found — skipping"; return 0; }

    local zip_size
    zip_size=$(du -sh "$zip_path" | cut -f1)
    log "Processing $zip_name ($zip_size)..."

    local tmp_dir
    tmp_dir="$TMP_DIR/embedded_zip_$(basename "$zip_path" .zip)_$$"
    mkdir -p "$tmp_dir"

    # Remove __MACOSX resource fork dir on extract — it confuses codesign
    if ! /usr/bin/unzip -oq "$zip_path" -d "$tmp_dir"; then
        log_err "Failed to extract $zip_name"
        rm -rf "$tmp_dir"
        return 1
    fi
    rm -rf "$tmp_dir/__MACOSX"

    local total_files
    total_files=$(/usr/bin/find "$tmp_dir" -type f | wc -l | tr -d ' ')
    log_sub "Extracted $total_files files from $zip_name"

    # ── Step 1: Find all code bundles (innermost first via depth sort) ────────
    local bundle_count=0
    local bundle_path
    # Sort by path depth (deepest first = innermost bundles first)
    while IFS= read -r bundle_path; do
        [[ -z "$bundle_path" ]] && continue
        local rel_bundle="${bundle_path#$tmp_dir/}"
        log_sub "Signing bundle: $rel_bundle"
        if codesign --force --options runtime --timestamp --sign "$APP_SIGN_ID" \
            "$bundle_path" 2>&1; then
            bundle_count=$((bundle_count + 1))
            log_sub "  ✅ $rel_bundle signed"
        else
            log_err "Failed to sign bundle: $rel_bundle"
            rm -rf "$tmp_dir"
            return 1
        fi
    done < <(/usr/bin/find "$tmp_dir" \( \
        -name "*.xpc" -o -name "*.app" -o -name "*.bundle" \
        -o -name "*.prefPane" -o -name "*.framework" -o -name "*.appex" \
    \) -type d | awk '{print length, $0}' | sort -rn | cut -d' ' -f2-)

    # ── Step 2: Sign standalone Mach-O binaries NOT inside any bundle ─────────
    local standalone_count=0
    local file_path
    while IFS= read -r -d '' file_path; do
        # Skip files inside a code bundle (already signed via bundle signing)
        local in_bundle=0
        for ext in ".xpc" ".app" ".bundle" ".prefPane" ".framework" ".appex"; do
            if [[ "$file_path" == *"$ext/"* ]]; then
                in_bundle=1
                break
            fi
        done
        [[ $in_bundle -eq 1 ]] && continue

        if /usr/bin/file "$file_path" | /usr/bin/grep -qi 'Mach-O'; then
            local rel_path="${file_path#$tmp_dir/}"
            if codesign --force --options runtime --timestamp --sign "$APP_SIGN_ID" \
                "$file_path" 2>&1; then
                standalone_count=$((standalone_count + 1))
                log_sub "Signed standalone: $rel_path"
            else
                log_err "Failed to sign standalone: $rel_path"
                rm -rf "$tmp_dir"
                return 1
            fi
        fi
    done < <(/usr/bin/find "$tmp_dir" -type f -print0)

    # ── Step 3: Verify signatures ─────────────────────────────────────────────
    local verify_ok=1
    while IFS= read -r bundle_path; do
        [[ -z "$bundle_path" ]] && continue
        if ! codesign --verify --deep --strict "$bundle_path" 2>&1; then
            log_warn "Verification warning for: ${bundle_path#$tmp_dir/}"
            verify_ok=0
        fi
    done < <(/usr/bin/find "$tmp_dir" \( \
        -name "*.xpc" -o -name "*.app" -o -name "*.bundle" \
        -o -name "*.prefPane" -o -name "*.framework" -o -name "*.appex" \
    \) -type d | awk '{print length, $0}' | sort -n | cut -d' ' -f2-)

    if [[ $verify_ok -eq 1 ]]; then
        log_sub "All bundle signatures verified ✅"
    fi

    # ── Step 4: Re-create zip using ditto (preserves macOS metadata) ──────────
    rm -f "$zip_path"
    (
        cd "$tmp_dir"
        /usr/bin/ditto -c -k --keepParent * "$zip_path"
    )
    local new_size
    new_size=$(du -sh "$zip_path" | cut -f1)
    rm -rf "$tmp_dir"

    log_ok "$zip_name: signed $bundle_count bundles + $standalone_count standalone binaries (new size: $new_size)"
}

# ══════════════════════════════════════════════════════════════════════════════
# Step 1/7: Refresh playwright.zip
# ══════════════════════════════════════════════════════════════════════════════
PLAYWRIGHT_SRC="$(dirname "$PROJECT_DIR")/playwright"
PLAYWRIGHT_ZIP="$PROJECT_DIR/$SCHEME/playwright.zip"

log_step "Step 1/7: Refresh playwright.zip"

if [[ -d "$PLAYWRIGHT_SRC" ]]; then
    log "Source: $PLAYWRIGHT_SRC"

    # Count source files (for logging)
    PW_FILE_COUNT=$(find "$PLAYWRIGHT_SRC" -type f \
        ! -path "*/node_modules/*" ! -path "*/.git/*" \
        ! -path "*/test-results/*" ! -path "*/graphify-out/*" \
        | wc -l | tr -d ' ')
    log_sub "Source files (before exclusions): $PW_FILE_COUNT"

    # Check if we need to rebuild
    REBUILD_ZIP=1
    CURRENT_CHECKSUM=""
    if [[ -f "$PLAYWRIGHT_ZIP" ]]; then
        OLD_PW_SIZE=$(du -sh "$PLAYWRIGHT_ZIP" | cut -f1)
        log_sub "Previous zip size: $OLD_PW_SIZE"

        # Calculate checksum of source files
        log_sub "Calculating source checksum..."
        CURRENT_CHECKSUM=$(find "$PLAYWRIGHT_SRC" -type f \
            ! -path "*/node_modules/*" ! -path "*/.git/*" \
            ! -path "*/test-results/*" ! -path "*/graphify-out/*" \
            ! -path "*/recoreded_jobs/drafts/*" \
            ! -path "*/webApp/uptime_logs/*" ! -name "run_log.json" \
            ! -name "test_history.json" ! -name "*.png" ! -name "*.jpg" ! -name "*.webm" \
            -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | awk '{print $1}')

        if [[ -f "${PLAYWRIGHT_ZIP}.checksum" ]]; then
            PREV_CHECKSUM=$(cat "${PLAYWRIGHT_ZIP}.checksum")
            if [[ "$CURRENT_CHECKSUM" == "$PREV_CHECKSUM" ]]; then
                log_sub "playwright source checksum matches (${CURRENT_CHECKSUM:0:8}...). Skipping rebuild."
                REBUILD_ZIP=0
            else
                log_sub "Checksum changed. Rebuilding..."
            fi
        else
            log_sub "No previous checksum found. Rebuilding..."
        fi
    else
        # Calculate checksum for the first time
        log_sub "Calculating source checksum..."
        CURRENT_CHECKSUM=$(find "$PLAYWRIGHT_SRC" -type f \
            ! -path "*/node_modules/*" ! -path "*/.git/*" \
            ! -path "*/test-results/*" ! -path "*/graphify-out/*" \
            ! -path "*/recoreded_jobs/drafts/*" \
            ! -path "*/webApp/uptime_logs/*" ! -name "run_log.json" \
            ! -name "test_history.json" ! -name "*.png" ! -name "*.jpg" ! -name "*.webm" \
            -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | awk '{print $1}')
    fi

    if [[ $REBUILD_ZIP -eq 1 ]]; then
        (cd "$PLAYWRIGHT_SRC" && zip -r --quiet "$PLAYWRIGHT_ZIP" . \
            --exclude "*/node_modules/*" --exclude "*/test-results/*" \
            --exclude "*/.git/*" --exclude "*/graphify-out/*" \
            --exclude "*/.DS_Store" --exclude "*/config.json" \
            --exclude "*/.auth*" --exclude "*/.preauth*" \
            --exclude "*/recoreded_jobs/drafts/*" \
            --exclude "*/webApp/uptime_logs/*" --exclude "*/webApp/run_log.json" \
            --exclude "*/webApp/test_history.json" \
            --exclude "**/*.png" --exclude "**/*.jpg" --exclude "**/*.webm")

        NEW_PW_SIZE=$(du -sh "$PLAYWRIGHT_ZIP" | cut -f1)
        log_ok "playwright.zip refreshed ($NEW_PW_SIZE)"
        
        if [[ -n "$CURRENT_CHECKSUM" ]]; then
            echo "$CURRENT_CHECKSUM" > "${PLAYWRIGHT_ZIP}.checksum"
        fi
    fi

    # Verify zip integrity
    if /usr/bin/unzip -tq "$PLAYWRIGHT_ZIP" >/dev/null 2>&1; then
        PW_ZIP_ENTRIES=$(unzip -l "$PLAYWRIGHT_ZIP" 2>/dev/null | tail -1 | awk '{print $2}')
        log_sub "Zip integrity: OK ($PW_ZIP_ENTRIES entries)"
    else
        die "playwright.zip is corrupt!"
    fi
else
    log_warn "playwright/ not found at $PLAYWRIGHT_SRC — skipping"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Step 2/7: Archive
# ══════════════════════════════════════════════════════════════════════════════
log_step "Step 2/7: xcodebuild Archive"
ARCHIVE_START=$(date +%s)

rm -rf "$ARCHIVE_PATH"
log "Project: $PROJECT"
log "Scheme:  $SCHEME"
log "Config:  Release"
log "Sign:    Manual / $APP_SIGN_ID"
log "Archive: $ARCHIVE_PATH"
log "▶ Archiving (this takes 1–5 min)..."

xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_IDENTITY="$APP_SIGN_ID" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE="Manual" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    MACOSX_DEPLOYMENT_TARGET=12.4 \
    2>&1 | tee "$RELEASE_DIR/xcodebuild_archive.log" \
    | grep -E "^error:|warning:.*signing|ARCHIVE SUCCEEDED|BUILD FAILED"

ARCHIVE_END=$(date +%s)
ARCHIVE_ELAPSED=$(( ARCHIVE_END - ARCHIVE_START ))

if grep -q "ARCHIVE SUCCEEDED" "$RELEASE_DIR/xcodebuild_archive.log"; then
    log_ok "Archive succeeded (${ARCHIVE_ELAPSED}s)"
else
    log_err "Archive FAILED after ${ARCHIVE_ELAPSED}s"
    log "Last 20 lines of build log:"
    tail -20 "$RELEASE_DIR/xcodebuild_archive.log"
    die "Archive failed — full log: $RELEASE_DIR/xcodebuild_archive.log"
fi

APP_IN_ARCHIVE="$ARCHIVE_PATH/Products/Applications/AnalyticsMacAgent.app"
[[ -d "$APP_IN_ARCHIVE" ]] || die ".app not found at $APP_IN_ARCHIVE"

# Log archive contents for debugging
APP_SIZE=$(du -sh "$APP_IN_ARCHIVE" | cut -f1)
log_sub "App size: $APP_SIZE"
log_sub "App contents:"
ls -la "$APP_IN_ARCHIVE/Contents/MacOS/" 2>/dev/null | while read -r line; do log_sub "  MacOS/ $line"; done || true
if [[ -d "$APP_IN_ARCHIVE/Contents/Helpers" ]]; then
    ls -la "$APP_IN_ARCHIVE/Contents/Helpers/" 2>/dev/null | while read -r line; do log_sub "  Helpers/ $line"; done || true
else
    log_sub "  Helpers/ (not present in archive — relauncher may be a separate target)"
fi

# Log embedded resources (playwright, iOS supervisor, NLC)
log_sub "Embedded resources:"
for res in "playwright.zip" "iOSSupervisorDependencies.zip" "Network Link Conditioner.prefPane.zip"; do
    RES_PATH="$APP_IN_ARCHIVE/Contents/Resources/$res"
    if [[ -f "$RES_PATH" ]]; then
        RES_SIZE=$(du -sh "$RES_PATH" | cut -f1)
        log_sub "  ✅ $res ($RES_SIZE)"
    else
        log_sub "  ⚠️  $res — NOT FOUND"
    fi
done

# Verify archive signatures
log "Verifying archive signatures..."
codesign --verify --deep --strict "$APP_IN_ARCHIVE" 2>&1 \
    && log_ok "Archive app signature: VALID" \
    || log_warn "Archive app signature has warnings"

# ══════════════════════════════════════════════════════════════════════════════
# Step 3/7: Export via xcodebuild -exportArchive (Developer ID)
# ══════════════════════════════════════════════════════════════════════════════
log_step "Step 3/7: Export (Developer ID Signing)"

rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

# Write ExportOptions.plist
EXPORT_OPTIONS="$RELEASE_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" << EXPORT_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingCertificate</key>
    <string>${APP_SIGN_ID}</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EXPORT_EOF
log_ok "ExportOptions.plist written"
log_sub "method=developer-id, signingStyle=manual, teamID=$TEAM_ID"

log "▶ Exporting archive..."
EXPORT_START=$(date +%s)
set +e
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    2>&1 | tee "$RELEASE_DIR/xcodebuild_export.log" \
    | grep -E "^error:|Export succeeded|EXPORT FAILED"
EXPORT_EXIT=${PIPESTATUS[0]}
set -e
EXPORT_END=$(date +%s)
EXPORT_ELAPSED=$(( EXPORT_END - EXPORT_START ))

EXPORTED_APP="$EXPORT_DIR/AnalyticsMacAgent.app"
USE_EXPORT=0

if [[ $EXPORT_EXIT -eq 0 && -d "$EXPORTED_APP" ]]; then
    USE_EXPORT=1
    EXPORT_SIZE=$(du -sh "$EXPORTED_APP" | cut -f1)
    log_ok "Export succeeded (${EXPORT_ELAPSED}s) — $EXPORT_SIZE"
    log_sub "Using Xcode-signed Developer ID app"

    codesign --verify --deep --strict "$EXPORTED_APP" 2>&1 \
        && log_ok "Exported app signature verified" \
        || log_warn "Exported app signature has warnings (may be OK)"
else
    log_warn "exportArchive failed (exit $EXPORT_EXIT, ${EXPORT_ELAPSED}s)"
    log_sub "This is common when no provisioning profile is installed for Developer ID"
    log_sub "Falling back to archive copy + manual signing in Step 4"

    # Show the actual error from the export log
    if [[ -f "$RELEASE_DIR/xcodebuild_export.log" ]]; then
        EXPORT_ERR=$(grep -E "^error:" "$RELEASE_DIR/xcodebuild_export.log" | head -5)
        if [[ -n "$EXPORT_ERR" ]]; then
            log_sub "Export errors:"
            echo "$EXPORT_ERR" | while read -r line; do log_sub "  $line"; done || true
        fi
    fi

    EXPORTED_APP="$EXPORT_DIR/AnalyticsMacAgent.app"
    cp -R "$APP_IN_ARCHIVE" "$EXPORTED_APP"
    log_ok "Copied app from archive for manual signing"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Step 4/7: Sign internals (inside-out, NO --deep)
# ══════════════════════════════════════════════════════════════════════════════
log_step "Step 4/7: Sign Internals (inside → out)"

STAGED_APP="$EXPORTED_APP"

# ── 4a. Helper binary ────────────────────────────────────────────────────────
STAGED_HELPER="$STAGED_APP/Contents/MacOS/com.gears42.Nix-Agent.AnalyticsMacAgent.Helper"
log "Checking helper binary..."
if [[ -f "$STAGED_HELPER" ]]; then
    HELPER_SIZE=$(du -sh "$STAGED_HELPER" | cut -f1)
    log_sub "Found: $(basename "$STAGED_HELPER") ($HELPER_SIZE)"
    if [[ $USE_EXPORT -eq 0 ]]; then
        log "Signing helper with Developer ID..."
        codesign --force --options runtime --timestamp --sign "$APP_SIGN_ID" \
            "$STAGED_HELPER" 2>&1 \
            && log_ok "Helper signed (Developer ID)" \
            || die "Helper signing FAILED"
    else
        codesign --verify "$STAGED_HELPER" 2>&1 \
            && log_ok "Helper signature OK (from export)" \
            || log_warn "Helper signature warning"
    fi
    # Show signing info
    codesign -dvv "$STAGED_HELPER" 2>&1 | grep -E "Authority|TeamIdentifier|Signature" | while read -r line; do log_sub "  $line"; done || true
else
    log_warn "Helper binary not found at expected path"
fi

# ── 4b. Relauncher binary ────────────────────────────────────────────────────
STAGED_RELAUNCHER="$STAGED_APP/Contents/Helpers/AnalyticsMacAgentRelauncher"
log "Checking relauncher binary..."
if [[ -f "$STAGED_RELAUNCHER" ]]; then
    RELAUNCH_SIZE=$(du -sh "$STAGED_RELAUNCHER" | cut -f1)
    log_sub "Found: $(basename "$STAGED_RELAUNCHER") ($RELAUNCH_SIZE)"
    if [[ $USE_EXPORT -eq 0 ]]; then
        log "Signing relauncher with Developer ID..."
        codesign --force --options runtime --timestamp --sign "$APP_SIGN_ID" \
            "$STAGED_RELAUNCHER" 2>&1 \
            && log_ok "Relauncher signed (Developer ID)" \
            || die "Relauncher signing FAILED"
    else
        codesign --verify "$STAGED_RELAUNCHER" 2>&1 \
            && log_ok "Relauncher signature OK (from export)" \
            || log_warn "Relauncher signature warning"
    fi
else
    log_warn "Relauncher binary not found — app may not auto-relaunch"
fi

# ── 4c. iOS Supervisor Dependencies zip ──────────────────────────────────────
IOS_SUPERVISOR_ZIP="$STAGED_APP/Contents/Resources/iOSSupervisorDependencies.zip"
log "Checking iOSSupervisorDependencies.zip..."
if [[ -f "$IOS_SUPERVISOR_ZIP" ]]; then
    IOS_ZIP_SIZE=$(du -sh "$IOS_SUPERVISOR_ZIP" | cut -f1)
    log_sub "Found: iOSSupervisorDependencies.zip ($IOS_ZIP_SIZE)"
    log "▶ Re-signing embedded Mach-O binaries inside iOSSupervisorDependencies.zip..."
    sign_embedded_zip_binaries "$IOS_SUPERVISOR_ZIP" \
        || die "iOSSupervisorDependencies.zip signing FAILED"
else
    log_warn "iOSSupervisorDependencies.zip not found in app Resources"
    log_sub "iOS device supervision features will not be available"
fi

# ── 4d. Network Link Conditioner zip ─────────────────────────────────────────
NLC_ZIP="$STAGED_APP/Contents/Resources/Network Link Conditioner.prefPane.zip"
log "Checking Network Link Conditioner.prefPane.zip..."
if [[ -f "$NLC_ZIP" ]]; then
    NLC_ZIP_SIZE=$(du -sh "$NLC_ZIP" | cut -f1)
    log_sub "Found: Network Link Conditioner.prefPane.zip ($NLC_ZIP_SIZE)"
    log "▶ Re-signing embedded Mach-O binaries inside NLC zip..."
    sign_embedded_zip_binaries "$NLC_ZIP" \
        || die "Network Link Conditioner zip signing FAILED"
else
    log_warn "Network Link Conditioner.prefPane.zip not found in app Resources"
    log_sub "Network throttling features will not be available"
fi

# ── 4e. Playwright zip — verify integrity (no signing needed, just data) ─────
STAGED_PW_ZIP="$STAGED_APP/Contents/Resources/playwright.zip"
log "Checking playwright.zip in app bundle..."
if [[ -f "$STAGED_PW_ZIP" ]]; then
    PW_STAGED_SIZE=$(du -sh "$STAGED_PW_ZIP" | cut -f1)
    log_sub "Found: playwright.zip ($PW_STAGED_SIZE)"
    if /usr/bin/unzip -tq "$STAGED_PW_ZIP" >/dev/null 2>&1; then
        log_ok "playwright.zip integrity verified"
    else
        log_warn "playwright.zip may be corrupt — postinstall extraction might fail"
    fi
else
    log_warn "playwright.zip not found in app Resources"
    log_sub "Playwright test automation will not be available"
fi

# ── 4f. Sign main app bundle LAST (seals everything inside) ──────────────────
log ""
if [[ $USE_EXPORT -eq 0 ]]; then
    log "▶ Signing main app bundle (Developer ID, no --deep)..."
    codesign --force --options runtime --timestamp --sign "$APP_SIGN_ID" \
        "$STAGED_APP" 2>&1 \
        && log_ok "Main app signed (Developer ID)" \
        || die "Main app signing FAILED"
else
    log "▶ Re-sealing main app bundle after zip modifications..."
    codesign --force --options runtime --timestamp --sign "$APP_SIGN_ID" \
        "$STAGED_APP" 2>&1 \
        && log_ok "Main app re-sealed" \
        || die "Main app re-sealing FAILED"
fi

# ── 4g. Final signature verification ─────────────────────────────────────────
log ""
log "── Final Signature Verification ──"
codesign --verify --deep --strict "$STAGED_APP" 2>&1 \
    && log_ok "Deep signature verification: PASSED" \
    || log_warn "Deep signature verification has warnings"

spctl --assess --type exec --verbose "$STAGED_APP" 2>&1 \
    && log_ok "Gatekeeper assessment: ACCEPTED" \
    || log_warn "Gatekeeper warning (normal before notarization)"

# Show signing chain
log "Signing chain:"
codesign -dvv "$STAGED_APP" 2>&1 | grep -E "Authority|TeamIdentifier|Signature|Info.plist" | while read -r line; do log_sub "$line"; done || true

# ══════════════════════════════════════════════════════════════════════════════
# Step 5/7: Build PKG — pkgbuild → productbuild → productsign
# ══════════════════════════════════════════════════════════════════════════════
log_step "Step 5/7: Build .pkg (pkgbuild → productbuild → productsign)"

rm -rf "$PKG_ROOT" "$PKG_BUILD_DIR"
mkdir -p "$PKG_ROOT/Applications" "$PKG_BUILD_DIR"

# ── 5a. Stage app into pkgroot ────────────────────────────────────────────────
log "Staging app into pkgroot..."
cp -R "$STAGED_APP" "$PKG_ROOT/Applications/"
STAGED_SIZE=$(du -sh "$PKG_ROOT" | cut -f1)
log_ok "App staged ($STAGED_SIZE)"

# ── 5b. Stage pkg_scripts ────────────────────────────────────────────────────
PKG_SCRIPTS_STAGE="$RELEASE_DIR/pkg_scripts_stage"
rm -rf "$PKG_SCRIPTS_STAGE"
mkdir -p "$PKG_SCRIPTS_STAGE"
cp "$PKG_SCRIPTS_SRC/preinstall"  "$PKG_SCRIPTS_STAGE/preinstall"
cp "$PKG_SCRIPTS_SRC/postinstall" "$PKG_SCRIPTS_STAGE/postinstall"
chmod +x "$PKG_SCRIPTS_STAGE/preinstall" "$PKG_SCRIPTS_STAGE/postinstall"
log_ok "pkg_scripts staged (preinstall + postinstall)"
log_sub "preinstall actions: kill app → stop daemons → remove old app → forget receipt → create uninstaller"
log_sub "postinstall actions: install helper → relauncher daemon → extract iOS supervisor → extract playwright → configure SiteInspector → launch app"

# ── 5c. Write component plist ────────────────────────────────────────────────
COMPONENT_PLIST="$PKG_BUILD_DIR/component.plist"
cat > "$COMPONENT_PLIST" << 'CPLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
  <dict>
    <key>BundleHasStrictIdentifier</key>
    <true/>
    <key>BundleIsRelocatable</key>
    <false/>
    <key>BundleIsVersionChecked</key>
    <true/>
    <key>BundleOverwriteAction</key>
    <string>upgrade</string>
    <key>RootRelativeBundlePath</key>
    <string>Applications/AnalyticsMacAgent.app</string>
  </dict>
</array>
</plist>
CPLIST_EOF
log_ok "Component plist written"
log_sub "BundleIsRelocatable=false, BundleOverwriteAction=upgrade"

# ── 5d. pkgbuild (component package, unsigned) ──────────────────────────────
COMPONENT_PKG="$PKG_BUILD_DIR/AnalyticsMacAgent_component.pkg"
log "▶ pkgbuild (component package)..."
pkgbuild \
    --root "$PKG_ROOT" \
    --component-plist "$COMPONENT_PLIST" \
    --scripts "$PKG_SCRIPTS_STAGE" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --install-location "/" \
    --ownership preserve \
    "$COMPONENT_PKG"
COMP_SIZE=$(du -sh "$COMPONENT_PKG" | cut -f1)
log_ok "Component package built ($COMP_SIZE)"

# ── 5e. Calculate install size ───────────────────────────────────────────────
INSTALL_KBYTES=$(du -sk "$COMPONENT_PKG" | cut -f1)
log_sub "Install size: ${INSTALL_KBYTES} KB ($(( INSTALL_KBYTES / 1024 )) MB)"

# ── 5f. Write distribution.xml ───────────────────────────────────────────────
DISTRIBUTION_XML="$PKG_BUILD_DIR/distribution.xml"
cat > "$DISTRIBUTION_XML" << DIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<installer-gui-script minSpecVersion="1.0">
    <options rootVolumeOnly="true"
             hostArchitectures="x86_64,arm64"
             customize="never"
             require-scripts="true"
             allow-external-scripts="no"/>
    <title>AnalyticsMacAgent</title>
    <organization>42Gears Mobility Systems</organization>

    <allowed-os-versions>
        <os-version min="12.0"/>
    </allowed-os-versions>

    <volume-check script="checkVolume();"/>
    <script>
    function checkVolume() {
        return true;
    }
    </script>

    <choices-outline>
        <line choice="installer_choice_main"/>
    </choices-outline>
    <choice id="installer_choice_main" title="AnalyticsMacAgent" description="Analytics Mac Agent by 42Gears">
        <pkg-ref id="${BUNDLE_ID}"/>
    </choice>
    <pkg-ref id="${BUNDLE_ID}" version="${VERSION}" auth="Root" installKBytes="${INSTALL_KBYTES}">AnalyticsMacAgent_component.pkg</pkg-ref>
    <bundle id="${BUNDLE_ID}" path="Applications/AnalyticsMacAgent.app" CFBundleShortVersionString="${VERSION}" BundleIsRelocatable="false"/>
</installer-gui-script>
DIST_EOF
log_ok "distribution.xml written"
log_sub "rootVolumeOnly=true, arch=x86_64+arm64, min macOS 12.0"

# ── 5g. productbuild (distribution package, unsigned) ────────────────────────
DISTRIBUTION_PKG="$PKG_BUILD_DIR/AnalyticsMacAgent_${VERSION}_unsigned.pkg"
log "▶ productbuild (distribution package)..."
productbuild \
    --distribution "$DISTRIBUTION_XML" \
    --package-path "$PKG_BUILD_DIR" \
    "$DISTRIBUTION_PKG"
DIST_SIZE=$(du -sh "$DISTRIBUTION_PKG" | cut -f1)
log_ok "Distribution package built, unsigned ($DIST_SIZE)"

# ── 5h. productsign (sign the distribution package) ──────────────────────────
PKG_SIGNED="$RELEASE_DIR/AnalyticsMacAgent_${VERSION}.pkg"
log "▶ productsign (signing with Developer ID Installer)..."
set +e
productsign --sign "$PKG_SIGN_ID" "$DISTRIBUTION_PKG" "$PKG_SIGNED" 2>&1
SIGN_EXIT=$?
set -e

if [[ $SIGN_EXIT -eq 0 ]]; then
    SIGNED_SIZE=$(du -sh "$PKG_SIGNED" | cut -f1)
    log_ok "Distribution package SIGNED ($SIGNED_SIZE)"
    log_sub "Signer: $PKG_SIGN_ID"
else
    log_warn "productsign failed (exit $SIGN_EXIT) — using unsigned package"
    cp "$DISTRIBUTION_PKG" "$PKG_SIGNED"
fi

# ── 5i. Verify the signed package ───────────────────────────────────────────
log ""
log "── Package Verification ──"
pkgutil --check-signature "$PKG_SIGNED" 2>&1 | while read -r line; do log_sub "$line"; done || true
log ""

# Quick payload listing to confirm what the PKG will install
log "── Package Payload ──"
pkgutil --payload-files "$COMPONENT_PKG" 2>/dev/null | head -30 | while read -r line; do log_sub "$line"; done || true
log_sub "... (showing first 30 entries)"

# ══════════════════════════════════════════════════════════════════════════════
# Step 6/7: Notarize + Staple
# ══════════════════════════════════════════════════════════════════════════════
log_step "Step 6/7: Notarize + Staple"
STAPLE_OK=0
if [[ $HAS_NOTARIZE -eq 1 ]]; then
    log "▶ Submitting for notarization (typically 1–10 min)..."
    log_sub "Package: $PKG_SIGNED"
    log_sub "Key ID:  $KEY_ID"
    log_sub "Issuer:  $ISSUER"
    log_sub "Team:    $TEAM_ID"

    NOTARY_JSON="$RELEASE_DIR/notary_result_${VERSION}.json"
    NOTARY_START=$(date +%s)
    set +e
    xcrun notarytool submit "$PKG_SIGNED" \
        --key "$KEY_FILE" \
        --key-id "$KEY_ID" \
        --issuer "$ISSUER" \
        --team-id "$TEAM_ID" \
        --wait \
        --timeout 30m \
        --output-format json > "$NOTARY_JSON" 2>&1
    NOTARY_EXIT=$?
    set -e
    NOTARY_END=$(date +%s)
    NOTARY_ELAPSED=$(( NOTARY_END - NOTARY_START ))

    if [[ $NOTARY_EXIT -ne 0 ]]; then
        log_err "Notarization command failed (exit $NOTARY_EXIT, ${NOTARY_ELAPSED}s)"
        cat "$NOTARY_JSON"
        die "Notarization submission failed"
    fi

    NOTARY_STATUS=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('status',''))" "$NOTARY_JSON" 2>/dev/null || echo "")
    NOTARY_ID=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('id',''))" "$NOTARY_JSON" 2>/dev/null || echo "")

    log "Notarization result (${NOTARY_ELAPSED}s):"
    log_sub "Submission ID: ${NOTARY_ID:-UNKNOWN}"
    log_sub "Status:        ${NOTARY_STATUS:-UNKNOWN}"

    if [[ "$NOTARY_STATUS" != "Accepted" ]]; then
        log_err "Notarization REJECTED — status: ${NOTARY_STATUS:-UNKNOWN}"
        echo ""
        log "── Fetching notarization log for details ──"
        if [[ -n "$NOTARY_ID" ]]; then
            NOTARY_LOG="$RELEASE_DIR/notary_log_${VERSION}.json"
            xcrun notarytool log "$NOTARY_ID" \
                --key "$KEY_FILE" \
                --key-id "$KEY_ID" \
                --issuer "$ISSUER" \
                --team-id "$TEAM_ID" \
                "$NOTARY_LOG" 2>&1 || true
            if [[ -f "$NOTARY_LOG" ]]; then
                log_sub "Log saved: $NOTARY_LOG"
                python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    issues = d.get('issues', [])
    if issues:
        print(f'   Found {len(issues)} issue(s):')
        for i, issue in enumerate(issues, 1):
            sev = issue.get('severity', '?')
            msg = issue.get('message', '?')
            path = issue.get('path', '?')
            print(f'   {i}. [{sev}] {msg}')
            print(f'      Path: {path}')
    else:
        print('   No specific issues listed in log')
except Exception as e:
    print(f'   Could not parse log: {e}')
" "$NOTARY_LOG" 2>/dev/null || true
            fi
        fi
        die "Notarization failed — fix the issues above and re-run"
    fi

    log_ok "Notarization ACCEPTED"

    # Staple with retry
    log "▶ Stapling ticket to .pkg (adaptive retries for CDN propagation)..."
    if staple_with_backoff "$PKG_SIGNED" "initial"; then
        STAPLE_OK=1
        xcrun stapler validate "$PKG_SIGNED" 2>&1 && log_ok "Staple validation: PASSED"
    else
        log_warn "Staple ticket not yet available — try later:"
        log_sub "xcrun stapler staple '$PKG_SIGNED'"
    fi
    xattr -rd com.apple.quarantine "$PKG_SIGNED" 2>/dev/null || true
else
    log "⏭  Skipping notarization (no AuthKey)"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Cleanup build artifacts
# ══════════════════════════════════════════════════════════════════════════════
log ""
log "Cleaning up intermediate files..."
rm -rf "$ARCHIVE_PATH"
# Remove old .pkg files (keep current version only)
find "$RELEASE_DIR" -maxdepth 1 -name "*.pkg" ! -name "AnalyticsMacAgent_${VERSION}.pkg" -delete
find "$RELEASE_DIR" -maxdepth 1 -name "*.zip" -delete
find "$RELEASE_DIR" -maxdepth 1 -name "*.xcarchive" -delete
# Keep xcodebuild logs for debugging
log_ok "Cleanup done — kept: .pkg, notary logs, xcodebuild logs"

# ══════════════════════════════════════════════════════════════════════════════
# Step 7/7: Auto-Install
# ══════════════════════════════════════════════════════════════════════════════
log_step "Step 7/7: Auto-Install"
if [[ -n "$INSTALL_USER" && -n "$INSTALL_PASS" ]]; then
    TMP_PKG="/tmp/AnalyticsMacAgent_${VERSION}.pkg"
    cp "$PKG_SIGNED" "$TMP_PKG"
    log "Package copied to $TMP_PKG"

    # Kill running app first
    log "▶ Stopping AnalyticsMacAgent..."
    killall "AnalyticsMacAgent" 2>/dev/null || true
    for i in 1 2 3 4 5; do
        pgrep -x "AnalyticsMacAgent" > /dev/null 2>&1 || break
        pkill -9 -x "AnalyticsMacAgent" 2>/dev/null || true
        sleep 1
    done
    # Also kill helper and relauncher
    pkill -f "com.gears42.Nix-Agent.AnalyticsMacAgent.Helper" 2>/dev/null || true
    log_ok "App + helper processes stopped"
    sleep 1

    # Install via osascript
    log "▶ Installing as '$INSTALL_USER'..."
    SCPT=$(mktemp /tmp/install_XXXXXX)
    INSTALL_LOG=$(mktemp /tmp/install_log_XXXXXX)
    cat > "$SCPT" <<SCPT_EOF
do shell script "installer -pkg '$TMP_PKG' -target /" user name "$INSTALL_USER" password "$INSTALL_PASS" with administrator privileges
SCPT_EOF

    INSTALL_START=$(date +%s)
    set +e
    osascript "$SCPT" > "$INSTALL_LOG" 2>&1
    INSTALL_EXIT=$?
    set -e
    INSTALL_END=$(date +%s)
    INSTALL_ELAPSED=$(( INSTALL_END - INSTALL_START ))
    rm -f "$SCPT"

    if [[ $INSTALL_EXIT -ne 0 ]]; then
        log_err "Install FAILED (exit $INSTALL_EXIT, ${INSTALL_ELAPSED}s)"
        log_sub "Error: $(cat "$INSTALL_LOG")"
        rm -f "$TMP_PKG" "$INSTALL_LOG"
        exit 1
    fi
    log_sub "installer output: $(cat "$INSTALL_LOG")"
    log_ok "Install completed (${INSTALL_ELAPSED}s)"
    rm -f "$INSTALL_LOG" "$TMP_PKG"

    sleep 1

    # Verify installation
    log "── Post-Install Verification ──"
    if [[ -d "/Applications/AnalyticsMacAgent.app" ]]; then
        INST_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "/Applications/AnalyticsMacAgent.app/Contents/Info.plist" 2>/dev/null || echo "?")
        INST_SIZE=$(du -sh "/Applications/AnalyticsMacAgent.app" | cut -f1)
        log_ok "App installed: /Applications/AnalyticsMacAgent.app"
        log_sub "Version: $INST_VER"
        log_sub "Size:    $INST_SIZE"
    else
        die "App NOT found in /Applications after install"
    fi

    # Check helper daemon
    if launchctl list 2>/dev/null | grep -q "AnalyticsMacAgent.Helper"; then
        log_ok "Helper daemon: RUNNING"
    else
        log_warn "Helper daemon not yet running (may start on next boot)"
    fi

    # Check relauncher daemon
    if launchctl list 2>/dev/null | grep -q "AnalyticsMacAgent.Relauncher"; then
        log_ok "Relauncher daemon: RUNNING"
    else
        log_warn "Relauncher daemon not yet running"
    fi

    # Verify postinstall extractions
    if [[ -d "/Library/Application Support/AnalyticsMacAgent/iOSSupervisor" ]]; then
        IOS_SUP_SIZE=$(du -sh "/Library/Application Support/AnalyticsMacAgent/iOSSupervisor" | cut -f1)
        log_ok "iOS Supervisor: extracted ($IOS_SUP_SIZE)"
    else
        log_sub "iOS Supervisor: not extracted (zip may not have been in bundle)"
    fi

    if [[ -d "/Library/Application Support/AnalyticsMacAgent/playwright" ]]; then
        PW_INST_SIZE=$(du -sh "/Library/Application Support/AnalyticsMacAgent/playwright" | cut -f1)
        log_ok "Playwright suite: extracted ($PW_INST_SIZE)"
    else
        log_sub "Playwright suite: not extracted"
    fi

    if [[ -f "/Library/Application Support/AnalyticsMacAgent/uninstall.sh" ]]; then
        log_ok "Uninstaller script: present"
    else
        log_warn "Uninstaller script: missing"
    fi

    # Final staple attempt
    if [[ $HAS_NOTARIZE -eq 1 && ${STAPLE_OK:-0} -eq 0 ]]; then
        log "▶ Retrying staple after install (CDN may have propagated by now)..."
        if staple_with_backoff "$PKG_SIGNED" "postinstall"; then
            STAPLE_OK=1
            log_ok "Stapled successfully after install"
        else
            log_warn "Staple still pending — run manually:"
            log_sub "xcrun stapler staple '$PKG_SIGNED'"
        fi
    fi
else
    log_warn "Skipping auto-install (no credentials in config.json)"
    log_sub "Expected keys: userToBeUsedForOperations + usersArray in $(dirname "$PROJECT_DIR")/config.json"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════════════
BUILD_END=$(date +%s)
BUILD_TOTAL=$(( BUILD_END - BUILD_START ))
BUILD_MIN=$(( BUILD_TOTAL / 60 ))
BUILD_SEC=$(( BUILD_TOTAL % 60 ))

open -R "$PKG_SIGNED"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  AnalyticsMacAgent v${VERSION} — BUILD COMPLETE              ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║  📦 PKG      → $PKG_SIGNED"
echo "║  📏 Size     → $(du -sh "$PKG_SIGNED" | cut -f1)"
echo "║  ⏱️  Duration → ${BUILD_MIN}m ${BUILD_SEC}s"
[[ $HAS_NOTARIZE -eq 1 ]] && [[ ${STAPLE_OK:-0} -eq 1 ]] && \
    echo "║  📋 Notarize → Accepted + Stapled ✅"
[[ $HAS_NOTARIZE -eq 1 ]] && [[ ${STAPLE_OK:-0} -eq 0 ]] && \
    echo "║  📋 Notarize → Accepted ✅ (staple pending)"
[[ -d "/Applications/AnalyticsMacAgent.app" ]] && \
    echo "║  🚀 Install  → /Applications/AnalyticsMacAgent.app"
echo "║  📂 Finder   → $RELEASE_DIR"
echo "║  📝 Log      → $BUILD_LOG_FILE"
echo "╚════════════════════════════════════════════════════════════╝"
