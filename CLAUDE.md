# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

SwiftForge is a native SwiftUI app (macOS + iOS/iPadOS) for practicing DSA and Swift/iOS interview questions offline: a code editor, a Swift execution engine, and a test-case runner, all running locally with no backend.

## Build & run

```bash
open SwiftForge.xcodeproj                    # open in Xcode (Cmd+R to run the "SwiftForge" scheme on "My Mac")
./run_app.sh                                  # builds Release for macOS + iOS (device or simulator), launches the .app, opens Xcode, tails execution logs
```

Manual xcodebuild equivalents (what `run_app.sh` wraps):

```bash
xcodebuild -project SwiftForge.xcodeproj -scheme SwiftForge -configuration Release \
  -derivedDataPath ./build/DerivedData CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES build

xcodebuild -project SwiftForge.xcodeproj -scheme SwiftForge -sdk iphonesimulator -configuration Release \
  -derivedDataPath ./build/DerivedData_iOS CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES build
```

Runtime execution logs stream to `~/Documents/swiftforge_execution.log`. There is no unit test target in this project — verification is done by running the app and exercising the DSA/Swift runner UI, not `xcodebuild test`.

### Packaging/release scripts — check before trusting

- `create_dmg.sh` builds `SwiftForge.dmg` and matches this project (references `SwiftForge.xcodeproj`).
- `build_pkg.sh` is templated from a *different* project (its `PROJECT`/`SCHEME`/`BUNDLE_ID` vars say `AnalyticsMacAgent`, not SwiftForge) — don't run it as-is; it needs those vars corrected first if it's ever adopted for this app.
- `fastlane mac release` (see `fastlane/Fastfile`) and `.github/workflows/deploy.yml` drive the real App Store/TestFlight release, triggered on `v*` tags.
- `.agents/AGENTS.md` mandates that after any code/config/view change, `./run_app.sh` must be run and its output/log inspected until clean — treat that as the project's definition of "done" for a change, not just a compile check.

## Architecture

MVVM with two ViewModels and one root view, all `@MainActor`:

- **`AppState`** (`ViewModels/AppState.swift`) — app-wide state: the full `[Question]` list, active tab (`.dsa` vs `.swiftPractice`, split by `Question.category`), and `UserActivity` (streak, solved IDs, per-question code drafts). Draft saves are debounced 800ms (`updateDraft`). Streak/activity logic lives here, not in a service.
- **`DSAPracticeViewModel`** — per-question editor/runner state: current question, editor `code`, console output, parsed `testcaseResults`. Owns the run lifecycle (`runCode()` → `CodeRunnerService` → parse results).
- **`ContentView`** — single root view branching on `horizontalSizeClass`/`os()` into a macOS/iPad split-pane workspace vs. an iOS compact tabbed workspace, plus an "Open Book" mode (solution pane + editor pane side by side, `Cmd+B`). No routing/navigation stack — panes are just conditionally-rendered subviews driven by `@State` enums (`WorkspaceFocusMode`, `DSAPaneTab`, `MobileWorkspaceTab`).

### Data: questions and fallback content

`DatabaseService.loadQuestions()` reads `dsa_questions.json` / `swift_questions.json` from the app bundle (or a local dev path). If either is missing or fails to decode, it falls back to Swift-literal `Question` arrays hardcoded directly in `DatabaseService.swift` — this makes that file huge (1300+ lines) and is intentional, not dead code. Each `Question` carries `templateCode`, `solutionCode`, and an optional `testHarness` (a full Swift script string appended to the user's code before execution).

### Code execution: dual-path runner (the core of the app)

`CodeRunnerService` (`Services/CodeRunnerService.swift`) runs user code two different ways:

1. **Primary (macOS only):** writes `code + testHarness` to a temp `.swift` file and shells out to `/usr/bin/swift` as a subprocess (5s timeout watchdog, output capped at 512KB, stdout/stderr captured via `Pipe`).
2. **Fallback (JS-in-process):** if the subprocess fails, or stderr mentions App Sandbox restrictions, `CodeRunnerService.transpileSwiftToJS` regex/brace-parses the Swift source into JS and evaluates it in a `JavaScriptCore` `JSContext` with hand-mocked stand-ins for `DispatchQueue`, `Task`, `URLSession`, `UserDefaults`, `PassthroughSubject`, etc. iOS always uses this path (no subprocess spawning there).

The transpiler is pattern-matching, not a real Swift parser — it handles the constructs already exercised by existing questions (classes/structs/actors, guard-let, if-let, trailing closures, `Task {}`, `for...in` ranges, `Array(repeating:count:)`, etc.) and will silently mistranspile anything novel. When adding a question whose solution uses new Swift syntax, manually check the JS fallback output.

`DSAPracticeViewModel.runJSFallback()` has a **hardcoded per-question-ID switch statement** (`two_sum`, `valid_parentheses`, `climb_stairs`, `rod_cutting`, `reverse_linked_list`, `maximal_square`) that re-supplies test cases in JS for the fallback path — the harness's Swift test cases don't survive transpilation as data, only as executed code. Any new question relying on the JS fallback path needs a matching `case` added here, or it silently runs with no test assertions.

Both execution paths produce output in the same sentinel format, parsed by `DSAPracticeViewModel.parseDSAResults` (splits lines on `" | "`):

```
---DSA_TEST_RESULTS_START---
CASE <n> | PASS|FAIL | Name: <name> | Output: <val> | Expected: <val> | Time: <ms>ms
SUMMARY | <passed>/<total> PASSED
---DSA_TEST_RESULTS_END---
```

New `testHarness` strings must print exactly this format or results won't render in `DSATestCasesView`/`ConsoleView`.

### Logging & persistence

- `LoggerService` wraps `os.Logger` with categories (`.codeRunner`, `.database`, `.ui`, `.network`, `.crash`) and file rotation; this is what feeds `~/Documents/swiftforge_execution.log`.
- `UserActivityService` persists `UserActivity` (streaks, solved questions, drafts) to a local JSON file — no network/backend involved anywhere in the app.

### Duplicated/backup source — don't edit these

`MyApp/.Views_backup.bundle/`, `.Models_backup.bundle/`, `.Services_backup.bundle/`, `.ViewModels_backup.bundle/`, `.Resources_backup.bundle/`, `.Assets.xcassets_backup.bundle/` are dot-prefixed backup copies of the real source directories (confirmed not referenced anywhere in `SwiftForge.xcodeproj/project.pbxproj`). The live code is in the non-`_backup` siblings (`MyApp/Views/`, `MyApp/Models/`, etc.) — always edit those, not the backups.

### Entitlements

`MyApp/SwiftForge.entitlements` currently has `com.apple.security.app-sandbox = false`. If that's ever flipped to `true` (required for Mac App Store distribution), the subprocess path in `CodeRunnerService` will fail for every run and the app falls back to the JS execution path for everything — that's expected, not a bug, but worth knowing when debugging "why did this suddenly go through JSContext."
