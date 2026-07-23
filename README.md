# ⚡️ CodeForge — DSA & Interview Prep for macOS

<div align="center">

  **A native, high-performance macOS & iOS app for mastering Data Structures, Algorithms, and Core iOS/Swift Engineering — 100% offline.**

  [![Version](https://img.shields.io/badge/version-2.0.0-orange?style=flat-square)](https://github.com/sachin6174/SwiftForge/releases/latest)
  [![macOS](https://img.shields.io/badge/macOS-12.0%2B-blue?style=flat-square&logo=apple&logoColor=white)](https://apple.com)
  [![iOS](https://img.shields.io/badge/iOS-15.0%2B-black?style=flat-square&logo=apple&logoColor=white)](https://apple.com)
  [![iPadOS](https://img.shields.io/badge/iPadOS-15.0%2B-purple?style=flat-square&logo=apple&logoColor=white)](https://apple.com)
  [![Homebrew](https://img.shields.io/badge/Homebrew-brew%20install--cask%20codeforge-FBB040?style=flat-square&logo=homebrew&logoColor=white)](https://github.com/sachin6174/homebrew-swiftforge)
  [![Swift](https://img.shields.io/badge/Swift-5.10%2B-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
  [![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-007ACC?style=flat-square)](https://developer.apple.com/xcode/swiftui/)
  [![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)
  [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](CONTRIBUTING.md)

  [Overview](#-overview) • [Key Features](#-key-features) • [Getting Started](#-getting-started) • [Architecture](#️-app-architecture) • [Track Highlights](#-track-highlights) • [Privacy](#-privacy--data)

</div>

---

## 📖 Overview

**CodeForge** (formerly *SwiftForge*) is a premium, native macOS + iOS application crafted specifically for iOS developers, Swift engineers, and computer science enthusiasts preparing for technical interviews. Unlike web-based coding platforms, CodeForge runs completely offline — no account, no network calls, no telemetry — delivering ultra-low-latency code execution, interactive test-case evaluation, custom data-structure visualizers, and targeted Swift language challenges, all on-device.

Whether you're preparing for senior iOS technical interviews, sharpening your algorithmic problem-solving in pure Swift, or deepening your knowledge of modern Swift concurrency and memory management, **CodeForge** provides a focused, distraction-free developer workspace.

> **New in 2.0.0:** the app has been renamed from SwiftForge to **CodeForge**, with an original app icon and a cleaned-up question list (no more numeric prefixes). See [Releases](https://github.com/sachin6174/SwiftForge/releases) for the full changelog.

---

## 📸 Screenshots

### 🖥️ macOS Workspace
Experience the fully integrated offline development environment with interactive visualizers, real-time local compiler output, and progress tracking:

<p align="center">
  <img src="mac-ss/Screen%20Shot%202026-07-07%20at%2013.21.16%20PM.png" width="49%" alt="macOS Workspace - Two Sum Challenge" />
  <img src="mac-ss/Screen%20Shot%202026-07-07%20at%2013.21.30%20PM.png" width="49%" alt="macOS Workspace - Reference Solution" />
</p>
<p align="center">
  <img src="mac-ss/Screen%20Shot%202026-07-07%20at%2013.21.40%20PM.png" width="49%" alt="macOS Workspace - Passing Test Suite" />
  <img src="mac-ss/Screen%20Shot%202026-07-07%20at%2013.21.49%20PM.png" width="49%" alt="macOS Workspace - Practice Track Switcher" />
</p>

### 📱 iOS Companion Interface
Perfect for practice on the go, with fully responsive glassmorphic layouts optimized for iOS:

<p align="center">
  <img src="ios-ss/Screen%20Shot%202026-07-07%20at%2013.09.20%20PM.png" width="24%" alt="iOS Workspace - Dashboard" />
  <img src="ios-ss/Screen%20Shot%202026-07-07%20at%2013.09.44%20PM.png" width="24%" alt="iOS Workspace - Code Editor" />
  <img src="ios-ss/Screen%20Shot%202026-07-07%20at%2013.10.11%20PM.png" width="24%" alt="iOS Workspace - Run Suite Results" />
  <img src="ios-ss/Screen%20Shot%202026-07-07%20at%2013.10.30%20PM.png" width="24%" alt="iOS Workspace - Daily Streak Tracker" />
</p>

---

## 🌟 Key Features

### 1. 🎯 Five Practice Tracks
- **DSA Practice**: Classic coding-interview algorithmic challenges (Arrays, Hash Maps, Linked Lists, Trees, Dynamic Programming, Graphs) written natively in idiomatic Swift, with a real code editor and test-case runner.
- **Swift & iOS Practice**: Real-world iOS concepts including ARC & retain cycles, `async`/`await` & Actors, Combine publishers, SwiftUI view hierarchy, value vs reference types, and protocol-oriented design.
- **MCQ Practice**: Rapid-fire multiple-choice questions for quick concept checks.
- **Machine Round**: Larger, system-design-style coding exercises modeled on real onsite "machine round" interview formats.
- **Q&A**: A reading/comprehension track — deep prose explanations paired with a runnable Swift example and key-takeaway bullets for each interview question (no test harness, unlike DSA/Swift Practice).

### 2. ⚡️ Dual-Path Code Execution Engine
- **macOS (unsandboxed dev builds)**: shells out to the local `/usr/bin/swift` toolchain to compile and run submitted code against the question's test harness.
- **Sandboxed / iOS builds**: since the shipping App Store build runs under `com.apple.security.app-sandbox`, subprocess spawning isn't available — code is instead transpiled from Swift to JavaScript and executed in-process via `JavaScriptCore`, with hand-built mocks for `DispatchQueue`, `Task`, `URLSession`, `UserDefaults`, `PassthroughSubject`, and more. This is the actual execution path for every real end user, not just a rare fallback.
- Instant console output capturing `stdout`, runtime errors, performance statistics, and per-case timing.

### 3. 🧪 Interactive Test Suite & Assertion Runner
- Comprehensive test case runner with side-by-side **Pass / Fail** indicators.
- Displays input parameters, expected vs. actual returns, execution time (ms), and exact diffs for failing cases.

### 4. 📊 2D Matrix & Data Structure Visualizer
- Dynamic grid visualizer for 2D array and matrix problems.
- Interactive node highlighting, row/column indices, and visual state rendering for grid traversal algorithms.

### 5. 🔥 Developer Analytics & Daily Streak Counter
- Automated daily activity logging and streak counter to foster consistent coding habits.
- Local JSON persistence for code drafts, solved badges, run counts, and progress tracking — no backend, no network calls.

### 6. 📖 Open Book Mode
- Side-by-side solution + editor pane (`Cmd+B` on macOS) for reading a reference solution while writing your own attempt.

### 7. 🎨 Glassmorphic Dark UI
- Built natively with SwiftUI using tailored dark modes, vibrant gradients, glowing focus rings, custom monospace code views with a hand-rolled line-number gutter, tactile press feedback, and responsive split-pane navigation.

---

## 🛠️ Tech Stack & Dependencies

| Layer | Technology | Description |
| :--- | :--- | :--- |
| **Framework** | SwiftUI | 100% native macOS + iOS/iPadOS user interface |
| **Language** | Swift 5.10+ | Modern Swift features, concurrency, and protocols |
| **Reactive Core**| Combine | State management, user activity streams, and event handlers |
| **Execution** | `/usr/bin/swift` subprocess + JavaScriptCore | Native subprocess runner on macOS, Swift-to-JS transpiler + `JSContext` everywhere sandboxing blocks subprocess spawning |
| **Persistence** | FileSystem JSON | Offline local database for challenges, drafts, & streaks — no backend |
| **Release** | Fastlane + Xcode Cloud / GitHub Actions | Automated build, notarization, and App Store Connect / TestFlight delivery |

---

## 🚀 Getting Started

### Option A — Install via Homebrew (recommended for just running the app)

```bash
brew tap sachin6174/swiftforge
brew install --cask codeforge
```

This installs a signed & notarized build straight from the [latest GitHub Release](https://github.com/sachin6174/SwiftForge/releases/latest) — no Xcode required. Update later with `brew upgrade --cask codeforge`.

> Previously installed via `brew install --cask swiftforge`? That cask still works and now installs the same CodeForge 2.0.0 app — new installs should use `codeforge`.

### Option B — Download directly

Grab the notarized `.dmg` from the [latest release](https://github.com/sachin6174/SwiftForge/releases/latest), open it, and drag **CodeForge** into Applications.

### Option C — Build from source

#### Prerequisites
- **macOS**: 12.0 (Monterey) or later
- **Xcode**: 15.0 or later
- **Swift Toolchain**: Swift 5.10+

#### Installation & Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/sachin6174/SwiftForge.git
   cd SwiftForge
   ```

2. **Open in Xcode**
   ```bash
   open SwiftForge.xcodeproj
   ```

3. **Build & run**
   - Select the `SwiftForge` scheme and **My Mac** as the run destination.
   - Press `Cmd + R` to build and launch the app.
   - Alternatively, use the convenience script, which builds both macOS and iOS, launches the app, opens Xcode, and tails execution logs:
     ```bash
     chmod +x run_app.sh
     ./run_app.sh
     ```

---

## 📚 Track Highlights

### 🔹 DSA Practice Track
Practice fundamental & advanced algorithms with Swift's strong type safety and standard library (`Array`, `Dictionary`, `Set`, custom data structures):

- **Two Sum**: Array hashing & optimal time complexity ($O(N)$).
- **Valid Parentheses**: Stack data structure operations.
- **Reverse Linked List**: Pointer manipulation & recursion.
- **Number of Islands**: Grid traversal via DFS/BFS.
- **LRU Cache**: Doubly-linked-list + hash-map design.
- **Course Schedule**: Topological sort / cycle detection.
- **Matrix Rotation / Search**: Grid navigation with the integrated Matrix Visualizer.

### 🔹 Swift & iOS Practice Track
Master critical concepts required for iOS engineering roles:

- **Value vs. Reference Types**: Deep dive into `struct` vs `class` semantics, copy-on-write (COW), and performance implications.
- **ARC & Retain Cycles**: Identifying `weak` vs `unowned` references to fix memory leaks.
- **Concurrency & Actors**: `async`/`await`, Task Groups, Actor isolation, and thread safety.
- **Combine Framework**: `PassthroughSubject`, `CurrentValueSubject`, operator chaining, and error handling.
- **SwiftUI State & Binding**: Understanding `@State`, `@StateObject`, `@ObservedObject`, and `@EnvironmentObject`.

### 🔹 MCQ Practice Track
Quick multiple-choice checks across Swift language fundamentals, iOS frameworks, and CS basics — for fast concept review between coding sessions.

### 🔹 Machine Round Track
Larger, open-ended coding exercises modeled on real "machine round" interview formats — more design surface than a single-function DSA problem.

### 🔹 Q&A Track
A reading-first track: each entry pairs a prose explanation with a runnable Swift example and key-takeaway bullets, for interview questions that are better understood than "solved" (e.g. actor reentrancy, memory model subtleties).

---

## 🏗️ App Architecture

CodeForge follows a clean, decoupled **MVVM (Model-View-ViewModel)** architecture, all `@MainActor`, paired with modular Service Layers:

```
SwiftForge/
├── MyApp/
│   ├── ContentView.swift              # Root view: macOS/iPad split-pane vs iOS compact tabbed workspace, Open Book mode
│   ├── ViewModels/
│   │   ├── AppState.swift             # App-wide state: question lists, active PracticeTab, streak/activity
│   │   └── DSAPracticeViewModel.swift # Per-question editor/runner state & run lifecycle
│   ├── Services/
│   │   ├── CodeRunnerService.swift    # Dual-path Swift execution: subprocess + JS/JavaScriptCore transpiler
│   │   ├── DatabaseService.swift      # Question loader (bundled JSON, with hardcoded Swift-literal fallback)
│   │   ├── UserActivityService.swift  # Streak, solved-set & code-draft persistence
│   │   └── LoggerService.swift        # os.Logger wrapper, categories, file rotation
│   ├── Models/
│   │   ├── Question.swift             # DSA / Swift Practice / Machine Round question schema
│   │   ├── MCQQuestion.swift          # Multiple-choice question schema
│   │   ├── QAItem.swift               # Q&A track: prose explanation + runnable example + takeaways
│   │   ├── QuestionSection.swift      # Grouped/sectioned question schema
│   │   ├── TestCase.swift             # Test input, expected & actual output
│   │   └── UserActivity.swift         # Daily history, streaks, drafts & solved set
│   ├── Views/
│   │   ├── SidebarView.swift          # Navigation sidebar, tab & category filters, streaks
│   │   ├── CodeEditorView.swift       # Syntax editor with custom SwiftUI line-number gutter
│   │   ├── DSADescriptionView.swift / DSASolutionView.swift / DSATestCasesView.swift
│   │   ├── MCQPracticeView.swift      # MCQ track UI
│   │   ├── QAPracticeView.swift       # Q&A track UI (interactive question reader)
│   │   ├── ConsoleView.swift          # Terminal output & log console
│   │   ├── SolvedCelebrationView.swift# Solve-confirmation feedback animation
│   │   ├── DesignSystem.swift         # Design tokens (colors, spacing, motion)
│   │   └── UIUtils.swift              # Shared buttons, badges & effects (incl. PressableButtonStyle)
│   └── Resources/
│       ├── dsa_questions.json / swift_questions.json / mcq_questions.json
│       ├── machine_round_questions.json / qa_questions.json
│       └── (DatabaseService also carries a large hardcoded fallback if these fail to load)
└── SwiftForge.xcodeproj               # Xcode Project Workspace
```

> **Naming note:** the shipped app is branded **CodeForge**, but the Xcode project file, scheme, and repository are still named `SwiftForge` intentionally (renaming those wasn't required and the Bundle ID must never change once published). See `CLAUDE.md` for the full explanation.

---

## 🎨 UI & Design System

CodeForge is built with a custom **Modern Dark Glassmorphism Design System**:

- **Color Palette**: Ultra-dark slate backgrounds (`#0F1117`, `#181B24`), glowing electric blue (`#3B82F6`), cyan (`#06B6D4`), vibrant orange (`#F97316`), and emerald green (`#10B981`).
- **Typography**: System Monospaced font for code views, SF Pro Display for clean UI navigation.
- **Visual Feedback**: Real-time pass/fail glow indicators, animated activity streak fire icons, and pulse animations.

---

## 🔒 Privacy & Data

CodeForge runs entirely offline. No account, no login, no analytics or tracking SDKs, no code you write ever leaves your device. Full details:

- [Privacy Policy](PRIVACY_POLICY.md)
- [Terms of Service / EULA](TERMS_OF_SERVICE.md)

---

## 🤝 Contributing

Contributions are always welcome! See [`CONTRIBUTING.md`](CONTRIBUTING.md) for how to add new DSA questions, Swift practice challenges, or UI visualizers.

---

## 📄 License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.

---

<div align="center">
  Crafted with ❤️ for the Swift & iOS Developer Community.
</div>
