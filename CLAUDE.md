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

**`DSAPracticeViewModel.runJSFallback()`'s hardcoded per-question-ID switch statement is dead code.** It's only reached when `CodeRunnerService.runSwiftCode` returns `exitCode == -2`, which nothing in that file ever returns — every actual fallback path (sandbox-restriction detection, subprocess-launch failure, and the iOS/non-macOS branch) returns `exitCode == 0` with the JS engine's own output, so `runCode()`'s `else` branch (`parseDSAResults`) handles it directly. Don't add cases to `runJSFallback()` expecting them to run.

**The transpiler was a near-total no-op for years and has since been substantially rewritten.** An initial investigation (extracting the exact transpiler logic into a standalone script and running it through real `JSContext`, not just reading the code) found that `CodeRunnerService.transpileSwiftToJS` silently mistranspiled essentially every question, including the six originals — the sandboxed/JS-only path had likely never actually worked for any non-trivial solution. Because this project's entitlements now require `com.apple.security.app-sandbox = true` for App Store/TestFlight distribution (see Entitlements below), the native `swift` subprocess path is unavailable on end users' Macs (most don't have the Swift toolchain installed at all) — making the JS engine the *only* execution path for real testers, not a rare fallback. This made fixing the transpiler a priority rather than optional cleanup.

Fixes applied (each independently confirmed via the verification technique below, using a standalone `swift <script>` run against a solution's actual `solutionCode + testHarness`, matching production exactly). This list grew across two passes — treat it as a catalog of "shapes of bugs this transpiler has", since more almost certainly remain for Swift syntax no current question happens to exercise:
- `transpileClassBody`'s stored-property/method splitter searched for literal `func`/`init`, but an earlier pass already renames those to `function`/`constructor` before the splitter ever runs — for any class with exactly one method and no prior properties (almost every `class Solution { func x() {...} }`), it found no boundary and stripped every `let`/`var` from the method body outright. Now searches for the post-rename tokens.
- `while` loops, plain `for x in collection {}` loops, and range-based `for x in a...b {}`/`for x in a..<b {}` loops all had ordering bugs relative to the trailing-closure pass (or, for `while`, no parenthesization at all).
- Call-site argument labels (`TestCase(nums: ..., target: ...)`, `limiter.allowRequest(currentTime: 0)`) were only stripped for a fixed whitelist of previously-seen names; any new/custom label silently produced invalid JS. `transpileClassInstantiations` now generally parses and strips labels for any call, with real paren/string-aware scanning (the old regex used `[^)]*`, which truncated at the first `)` and broke on nested calls or a string literal containing a stray paren) — and recurses into each argument (`stripCallSiteLabels`), since an argument can itself be a trailing closure containing further calls that also need converting.
- Swift's implicit memberwise struct initializer (`struct TestCase { let a: T; let b: U }`, used by literally every test harness's helper struct) had no representation at all — `transpileClassBody` now synthesizes one when no explicit `init`/method is found.
- Implicit `self` member access (calling a sibling method or reading a property without `self.`) was only special-cased for a 4-name hardcoded whitelist left over from one earlier question. `addThisPrefixWithinMethodBodies` now does this generally per-class, scanning method bodies only (never parameter lists, to avoid corrupting a parameter that happens to share a property's name — a very common pattern for initializers). It does NOT skip string/template-literal content, so a property/method name that happens to also be a substring used as literal text (e.g. a method named `withdraw` and a log string `"withdraw \(amount)"`) can still get wrongly prefixed — a known remaining gap (see `actor_reentrancy_bug_fix` below).
- Non-empty dictionary literals (`[")": "(", "]": "["]`), `Set<Character> = [...]` literals, `[Type]()`/`[Type](repeating:count:)` array constructors, range subscripts (`arr[a..<b]`), `.sorted(by: >/<)`, `.sorted { closure }` (needs `.slice()` first since JS arrays have no `.sorted`, plus the closure's boolean return needs converting to a `-1/1` comparator — a bare boolean gets silently coerced to `0/1`, which is not a valid comparator and produces a wrong, inconsistent sort), `.swapAt`, `.contains`/`.dropFirst`/`.joined`/`.rounded` (Array/Double methods with different JS names), `.last`/`.first` (no JS equivalent property), Swift string interpolation (`"\(expr)"`) in general, and default parameter values (`cost: Int = 1`, previously dropped entirely) all had no conversion path before.
- The runtime JS mock header overrode the global `Set` with an incomplete `MockSet` (no `.has()`, no iterable constructor) — removed so solutions get the real, fully-capable ES6 `Set`.
- Swift's discard pattern (`_ = someCall()`) was treated as a real assignment to a variable named `_`; inside a `for _ in 0..<n { _ = ... }` loop this silently overwrote the loop's own counter with the call's return value every iteration — a genuine infinite loop at runtime, not just a wrong answer, discovered when a test run hung indefinitely. Now stripped to a bare expression statement.
- Bare `Array(x)` (Swift's "convert String/Sequence to Array" idiom) was wrapped as `new Array(x)`, a different JS operation entirely (creates a 1-element array, or an empty array if `x` is a number) — now correctly becomes `Array.from(x)`, while the `Array(repeating:count:)` initializer form still gets `new Array(n).fill(v)`.
- `transpileClassBlocks` reused a `String.Index` captured against the string value BEFORE `result = prefix + processedBody + suffix` reassigned it to a newly-concatenated String — undefined behavior in Swift (indices aren't portable across different String values) that happened to silently land in the right place for many earlier questions, then landed a couple characters early for one solution once the preceding processed body's length changed, truncating an identifier (`intervals` → `tervals`) and corrupting the next class declaration. Now recomputed from `result.startIndex` with character counts, which is always correct regardless of storage.
- A closure-parameter-detection regex (`\{\s*([\w,\s\[\]]+)\s+in`, for `{ x in ... }`) had no word boundary after `in`, so it also matched just the first two letters of any identifier starting with "in" immediately after an opening brace (e.g. `class TestCase {\n    intervals = ...` — the whitespace between `{` and `intervals` gets split between the capture group and the required `\s+`, landing exactly on `in`, the first two letters of `intervals`). Now requires `in\b`.
- `guard`/`if`/`while` with multiple comma-separated conditions (`guard !a.isEmpty, !b.isEmpty else {...}`, `if let x = expr, cond {...}`, `if cond, let x = expr, cond2 {...}`, `while let x = arr.last, cond {...}`) each needed dedicated handling — the plain single-condition regexes otherwise capture the whole comma-separated list as one opaque expression, producing either a JS comma-operator bug (silently discards every condition but the last one — a correctness bug, not a crash) or an outright syntax error.
- Swift's `arr[key, default: []].append(x)` idiom needed its own conversion; the default-value capture group's `[^\]]+` broke on the `]` inside its own most common default value (`[]`), desyncing the match. The fixed conversion also needs a leading `;` — its parenthesized-comma-expression output otherwise merges with whatever non-terminated statement precedes it via JS's automatic semicolon insertion, referencing a `const` inside its own initializer (a temporal-dead-zone `ReferenceError`).
- Nested type declarations (`private class Node {...}` declared inside `class LRUCache {...}`, the standard Swift pattern for a linked-list-style helper type used by one containing type) are not valid JS at all — a JS class body can only contain members, not another class declaration. `hoistNestedTypeDeclarations` now hoists any such nested declaration to a sibling top-level declaration immediately before its former container, preserving relative order everywhere else in the file.
- `x!.property` (force-unwrap immediately followed by member access, e.g. `curr!.next`) wasn't covered by either existing force-unwrap regex (one requires a preceding function call, the other requires `!` followed by a comma/brace/bracket/whitespace/end — not a literal `.`).
- Optional-chaining ASSIGNMENT (`curr?.next = prev`) is valid Swift but invalid JS — `?.` can only be used to read/call through a chain, never as an assignment target (`a?.b = c` is a JS SyntaxError). Rewritten as a guarded assignment (`if (curr) { curr.next = prev; }`).

**Current verified state:** of the 20 DSA questions, 19 pass their full test suite (`N/N PASSED`) end-to-end through the real transpiler + `JSContext`: every question except `lru_cache_design`. Re-verify this list before trusting it, since further edits may have changed it — see the verification technique below. Known remaining gaps, not yet fixed:
- `lru_cache_design`: an `if let node = dict[key] { ... }`-style binding hoisted to `const node = ...; if (...) {...}` leaks `node` into the enclosing function scope (JS `const`/`let` there are block-scoped only within an extra `{}` this transpiler doesn't add), which throws "already declared" if the same function later declares another `node` with `let`/`var` — a very common pattern (check the cache, and if absent, create a new entry with the same variable name).
- `todo_command_processor` (a `swiftPractice`-category question, not counted in the 20): needs full `switch`/`case` support, which doesn't exist in the pipeline at all yet — Swift `case` bodies don't fall through by default but JS's do, so every case needs a synthesized `break` at minimum, and `guard let x = arr.first` (the `.first` property fix only covers property reads outside guard/if/while binding contexts).
- `actor_reentrancy_bug_fix` (`swiftPractice`, not counted in the 20): stacks several separate gaps at once — `private(set)` (compound access-modifier syntax, not stripped by the plain `private`/`public`/etc. regex), implicit `return` for a single-expression ordinary function/method body (only closures get this treatment via `wrapImplicitReturnIfNeeded`; `func currentBalance() -> Int { balance }` has no return added at all), `async` appearing between a parameter list and `->` (the return-type-stripping regex expects `)` immediately followed by `->`, not `) async ->`), and the `this.`-prefixing gap noted above (a string literal `"withdraw \(amount)"` had `withdraw` wrongly turned into `this.withdraw` since it happens to match a real method name on the same class).

**Verification technique:** build the exact runtime input (`import Foundation\nimport Dispatch\n` + `solutionCode` + `\n\n` + `testHarness`, matching `CodeRunnerService.runSwiftCode`'s own auto-import logic) and run it through a standalone copy of `transpileSwiftToJS`/`runJSCode` compiled as a plain `swift` script — reading the transpiler's code alone is not sufficient, several of the bugs above were only visible by actually executing the output in `JSContext`. Keep any such standalone copy byte-for-byte in sync with the real file when making further changes; a drifted copy gives false confidence.

Question content lives in `MyApp/Resources/dsa_questions.json` / `swift_questions.json`, which are what actually get bundled and loaded at runtime (checked before the Swift-literal fallback arrays in `DatabaseService.swift` — see above). The two must be kept in sync manually; adding a question only to the fallback arrays without also adding it to these JSON files means it silently never appears in the running app.

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

`MyApp/SwiftForge.entitlements` has `com.apple.security.app-sandbox = true` (also `com.apple.security.cs.allow-jit = true`, for `JavaScriptCore`'s JIT under Hardened Runtime) — required for App Store Connect to accept a build at all; an unsandboxed `.app` is rejected outright at upload/validation time with "App sandbox not enabled." With sandboxing on, the subprocess path in `CodeRunnerService` fails for every run (real Macs without Xcode/the Swift command-line toolchain installed don't even have `/usr/bin/swift` to spawn) and the app falls back to the JS execution path for everything — that's expected, not a bug, but it does mean the JS transpiler's correctness (see above) now directly determines whether grading works at all for real users, not just as a rare degraded-mode fallback.
