# SwiftForge Agent Mandatory Rules & Automated Workflow

## STAGE 1: Mandatory Post-Change App Execution
After modifying any code, configuration, or view file:
1. **Execute `./run_app.sh`**:
   - MUST run `./run_app.sh` via `run_command`. This compiles the Release build, launches the native `.app` binary on macOS, opens Xcode, and streams the execution logs.
2. **Observe Logs Continuously**:
   - Inspect the build output and runtime log file (`~/Documents/swiftforge_execution.log`).
   - Look for any errors, warnings, JS exceptions (`JS Exception:`), sandbox warnings, or failed test suite cases.

## STAGE 2: Automated Self-Healing Loop
1. If ANY failure or warning appears in `swiftforge_execution.log` or build logs:
   - Immediately debug the root cause.
   - Apply fixes to the source code.
   - Re-run `./run_app.sh` and re-inspect the logs in an automated loop until all logs show `[SUCCESS]` and zero exceptions.

## STAGE 3: Cross-Platform Verification
- Validate both `macOS` and `iOS Simulator` build targets:
  - `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project SwiftForge.xcodeproj -scheme SwiftForge -configuration Release -derivedDataPath ./build/DerivedData build`
  - `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project SwiftForge.xcodeproj -scheme SwiftForge -sdk iphonesimulator -configuration Release -derivedDataPath ./build/DerivedData_iOS build`
