#!/bin/bash
# ==============================================================================
# SwiftForge — Total Removal Script
#
# Removes every trace of SwiftForge from this Mac:
#   - the installed app (Homebrew cask install AND/or a manually copied .app)
#   - the Homebrew tap + cask
#   - all user data: prefs, caches, container sandbox data, saved state,
#     crash reports, execution logs
#   - all Xcode build artifacts: DerivedData, Archives
#   - any copy installed on an iOS Simulator or a paired physical iOS device
#   - stray copies anywhere else on disk (found via Spotlight + a targeted
#     filesystem sweep of common locations)
#   - THIS SOURCE REPOSITORY ITSELF (git history, uncommitted work, everything)
#
# This is irreversible. There is no backup step. Once this script finishes,
# nothing named SwiftForge that this script can find will still exist on
# this machine, including the folder this script lives in.
# ==============================================================================
set -uo pipefail

BUNDLE_ID="in.sachinserver.swiftforge"
APP_NAME="SwiftForge"
TAP_NAME="sachin6174/swiftforge"
CASK_NAME="swiftforge"
REPO_DIR="/Users/sachinkumar/Desktop/SwiftForge-ios-mac-web"

say()  { echo "==> $*"; }
skip() { echo "    (not found, skipping) $*"; }

# ------------------------------------------------------------------------
# 0. Confirmation gate — this is destructive and irreversible.
# ------------------------------------------------------------------------
echo "===================================================================="
echo " This will PERMANENTLY delete:"
echo "   - the SwiftForge.app, wherever installed"
echo "   - the Homebrew cask + tap ($TAP_NAME)"
echo "   - all SwiftForge app data, caches, prefs, crash reports, logs"
echo "   - all Xcode DerivedData / Archives for SwiftForge"
echo "   - any copy on an iOS Simulator or paired iPhone"
echo "   - stray copies anywhere else found on disk"
echo "   - THE SOURCE REPO ITSELF: $REPO_DIR (git history included)"
echo "===================================================================="
read -r -p "Type EXACTLY 'DELETE SWIFTFORGE' to proceed: " CONFIRM
if [ "$CONFIRM" != "DELETE SWIFTFORGE" ]; then
    echo "Confirmation did not match. Aborting — nothing was deleted."
    exit 1
fi

# ------------------------------------------------------------------------
# 1. Quit any running instance
# ------------------------------------------------------------------------
say "Quitting any running SwiftForge process..."
osascript -e 'tell application "SwiftForge" to quit' >/dev/null 2>&1 || true
pkill -f "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" 2>/dev/null && say "Killed running process." || skip "no running process"
sleep 1

# ------------------------------------------------------------------------
# 2. Homebrew cask + tap
# ------------------------------------------------------------------------
if command -v brew >/dev/null 2>&1; then
    if brew list --cask "$CASK_NAME" >/dev/null 2>&1; then
        say "Uninstalling Homebrew cask ($CASK_NAME) with --zap..."
        brew uninstall --cask --zap --force "$CASK_NAME" 2>&1 || true
    else
        skip "Homebrew cask $CASK_NAME not installed"
    fi

    if brew tap | grep -qx "$TAP_NAME"; then
        say "Untapping $TAP_NAME..."
        brew untap "$TAP_NAME" 2>&1 || true
    else
        skip "tap $TAP_NAME not present"
    fi

    if [ -d "/opt/homebrew/Caskroom/${CASK_NAME}" ]; then
        say "Removing leftover Caskroom directory..."
        rm -rf "/opt/homebrew/Caskroom/${CASK_NAME}"
    fi

    BREW_CACHE="$(brew --cache 2>/dev/null || true)"
    if [ -n "$BREW_CACHE" ] && [ -d "$BREW_CACHE" ]; then
        while IFS= read -r -d '' p; do
            say "Removing cached download: $p"
            rm -rf "$p"
        done < <(find "$BREW_CACHE" -iname "*${APP_NAME}*" -print0 2>/dev/null)
    fi
else
    skip "Homebrew not installed"
fi

# ------------------------------------------------------------------------
# 3. The .app bundle itself, wherever it landed
# ------------------------------------------------------------------------
for app_path in "/Applications/${APP_NAME}.app" "$HOME/Applications/${APP_NAME}.app"; do
    if [ -e "$app_path" ]; then
        say "Removing $app_path"
        rm -rf "$app_path"
    else
        skip "$app_path"
    fi
done

# ------------------------------------------------------------------------
# 4. Per-user app data (sandbox container, prefs, caches, saved state, logs)
# ------------------------------------------------------------------------
USER_DATA_PATHS=(
    "$HOME/Library/Containers/${BUNDLE_ID}"
    "$HOME/Library/Caches/${BUNDLE_ID}"
    "$HOME/Library/Preferences/${BUNDLE_ID}.plist"
    "$HOME/Library/Saved Application State/${BUNDLE_ID}.savedState"
    "$HOME/Library/HTTPStorages/${BUNDLE_ID}"
    "$HOME/Library/HTTPStorages/${BUNDLE_ID}.binarycookies"
    "$HOME/Library/WebKit/${BUNDLE_ID}"
    "$HOME/Library/Application Support/${APP_NAME}"
    "$HOME/Documents/swiftforge_execution.log"
)
for p in "${USER_DATA_PATHS[@]}"; do
    if [ -e "$p" ]; then
        say "Removing $p"
        rm -rf "$p"
    else
        skip "$p"
    fi
done

# Crash reports / diagnostic reports (filename-suffixed with a UUID, so glob)
shopt -s nullglob
for p in "$HOME/Library/Application Support/CrashReporter/${APP_NAME}"_*.plist \
         "$HOME/Library/Logs/DiagnosticReports/${APP_NAME}"_* \
         "$HOME/Library/Logs/DiagnosticReports/${APP_NAME}-"* ; do
    say "Removing $p"
    rm -rf "$p"
done
shopt -u nullglob

# ------------------------------------------------------------------------
# 5. Xcode build artifacts: DerivedData + Archives
# ------------------------------------------------------------------------
shopt -s nullglob
for p in "$HOME/Library/Developer/Xcode/DerivedData/${APP_NAME}"-*; do
    say "Removing DerivedData $p"
    rm -rf "$p"
done
shopt -u nullglob

while IFS= read -r -d '' archive; do
    say "Removing Xcode archive $archive"
    rm -rf "$archive"
done < <(find "$HOME/Library/Developer/Xcode/Archives" -iname "${APP_NAME}*.xcarchive" -print0 2>/dev/null)

# ------------------------------------------------------------------------
# 6. iOS Simulators — uninstall from every simulator that has it, not just booted
# ------------------------------------------------------------------------
if command -v xcrun >/dev/null 2>&1; then
    say "Scanning iOS Simulators for installed copies..."
    SIM_UDIDS=$(xcrun simctl list devices -j 2>/dev/null | \
        python3 -c "import json,sys; d=json.load(sys.stdin); print('\n'.join(x['udid'] for v in d['devices'].values() for x in v))" 2>/dev/null)
    while IFS= read -r udid; do
        [ -z "$udid" ] && continue
        if xcrun simctl get_app_container "$udid" "$BUNDLE_ID" >/dev/null 2>&1; then
            say "Uninstalling from simulator $udid"
            xcrun simctl uninstall "$udid" "$BUNDLE_ID" 2>&1 || true
        fi
    done <<< "$SIM_UDIDS"
fi

# ------------------------------------------------------------------------
# 7. Paired physical iOS device (best effort — requires the device to be
#    reachable; devicectl has no universal "uninstall by bundle id" that
#    works offline, so this is attempted but not guaranteed).
# ------------------------------------------------------------------------
if command -v xcrun >/dev/null 2>&1; then
    say "Checking paired iOS devices for an installed copy..."
    DEVICE_IDS=$(xcrun devicectl list devices 2>/dev/null | awk 'NR>2 {print $(NF-1)}')
    while IFS= read -r dev; do
        [ -z "$dev" ] && continue
        if xcrun devicectl device info apps --device "$dev" 2>/dev/null | grep -qi "$BUNDLE_ID"; then
            say "Uninstalling from device $dev"
            xcrun devicectl device uninstall app --device "$dev" "$BUNDLE_ID" 2>&1 || true
        fi
    done <<< "$DEVICE_IDS"
fi
echo "    NOTE: if SwiftForge was ever installed on a physical iPhone/iPad via"
echo "    Xcode's 'Run' (not TestFlight/App Store), and that device isn't"
echo "    currently reachable, you'll need to delete it by hand from the device."

# ------------------------------------------------------------------------
# 8. Trash
# ------------------------------------------------------------------------
find "$HOME/.Trash" -iname "*${APP_NAME}*" -maxdepth 1 -print0 2>/dev/null | while IFS= read -r -d '' p; do
    say "Removing from Trash: $p"
    rm -rf "$p"
done

# ------------------------------------------------------------------------
# 9. Broad sweep for stray copies anywhere else on disk
# ------------------------------------------------------------------------
say "Sweeping Spotlight index for any remaining SwiftForge items..."
mdfind "kMDItemFSName == '${APP_NAME}*'cd" 2>/dev/null | while IFS= read -r p; do
    [ -e "$p" ] || continue
    say "Removing stray item: $p"
    rm -rf "$p"
done

say "Sweeping common user directories for stray copies..."
for root in "$HOME/Desktop" "$HOME/Downloads" "$HOME/Documents" "/Applications" "/opt/homebrew"; do
    [ -d "$root" ] || continue
    find "$root" -maxdepth 4 -iname "*${APP_NAME}*" ! -path "$REPO_DIR" ! -path "$REPO_DIR/*" -print0 2>/dev/null | \
    while IFS= read -r -d '' p; do
        say "Removing stray item: $p"
        rm -rf "$p"
    done
done

# ------------------------------------------------------------------------
# 10. Finally, the source repository itself (must be last: earlier steps
#     don't depend on it, and this script is being read into the shell's
#     memory already so deleting its own containing folder mid-run is safe).
# ------------------------------------------------------------------------
if [ -d "$REPO_DIR" ]; then
    say "Removing source repository: $REPO_DIR"
    rm -rf "$REPO_DIR"
else
    skip "$REPO_DIR"
fi

echo "===================================================================="
echo " SwiftForge has been completely removed from this system."
echo "===================================================================="
