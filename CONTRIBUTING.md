# Contributing to CodeForge

Thanks for your interest in improving CodeForge! Contributions of new DSA questions, Swift/iOS practice challenges, visualizers, and bug fixes are welcome.

## Getting set up

1. Fork the repository and clone your fork
2. `open SwiftForge.xcodeproj` and build the `SwiftForge` scheme on **My Mac**
3. After any change, run `./run_app.sh` and check its output/log before opening a PR — this is the project's baseline check since there's no unit test target

## Adding a new question

Question content lives in `MyApp/Resources/*.json` (bundled at runtime) and is mirrored in `DatabaseService.swift`'s hardcoded fallback arrays (used only if the JSON fails to load). **Both must be kept in sync** — a question added to only one silently never appears in the running app.

If your solution's reference code uses Swift syntax not already exercised by existing questions, manually verify the JS fallback transpiler output (see `CLAUDE.md` for the transpiler's known limitations) — sandboxed builds (including every App Store build) execute exclusively through it, never through a real Swift compiler.

## Submitting changes

1. Create a feature branch: `git checkout -b feature/my-change`
2. Commit your changes with a clear message
3. Push and open a Pull Request describing what changed and why

## Reporting issues

Please use [GitHub Issues](https://github.com/sachin6174/SwiftForge/issues) for bug reports and feature requests.
