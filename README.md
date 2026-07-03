# ⚡️ SwiftForge — DSA & iOS Studio for macOS

<div align="center">

  ![SwiftForge Logo](https://img.shields.io/badge/SwiftForge-DSA%20%26%20iOS%20Studio-orange?style=for-the-badge&logo=swift&logoColor=white)

  **A native, high-performance macOS IDE for mastering Data Structures, Algorithms, and Core iOS/Swift Engineering.**

  [![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue?style=flat-square&logo=apple&logoColor=white)](https://apple.com)
  [![Swift](https://img.shields.io/badge/Swift-5.10%2B-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
  [![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-007ACC?style=flat-square&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
  [![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)
  [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](CONTRIBUTING.md)

  [Key Features](#-key-features) • [App Architecture](#-app-architecture) • [Getting Started](#-getting-started) • [Track Highlights](#-track-highlights) • [UI & Design](#-ui--design-system)

</div>

---

## 📖 Overview

**SwiftForge** is a premium, native macOS application crafted specifically for iOS developers, Swift engineers, and computer science enthusiasts. Unlike web-based coding platforms, SwiftForge runs completely offline on your Mac, delivering ultra-low latency code execution, interactive test case evaluations, custom data structure visualizers, and targeted Swift language challenges.

Whether you're preparing for senior iOS technical interviews, sharpening your algorithmic problem-solving in pure Swift, or deepening your knowledge of modern Swift concurrency and memory management, **SwiftForge** provides the ultimate focused developer workspace.

---

## 🌟 Key Features

### 1. 🎯 Dual Practice Tracks
- **DSA Practice Track**: LeetCode-style algorithmic challenges (Arrays, Hash Maps, Linked Lists, Trees, Dynamic Programming, Graphs) written natively in idiomatic Swift.
- **Swift & iOS Practice Track**: Real-world iOS concepts including ARC & retain cycles, `async`/`await` & Actors, Combine publishers, SwiftUI view hierarchy, value vs reference types, and protocol-oriented design.

### 2. ⚡️ Local Code Runner & Execution Engine
- Evaluates Swift code in real-time using a lightweight, native execution pipeline.
- Instant console output capturing `stdout`, runtime errors, performance statistics, and memory usage.

### 3. 🧪 Interactive Test Suite & Assertion Runner
- Comprehensive test case runner with side-by-side **Pass / Fail** indicators.
- Displays input parameters, expected vs. actual returns, execution time (ms), and exact diffs for failing cases.

### 4. 📊 2D Matrix & Data Structure Visualizer
- Dynamic grid visualizer for 2D array and matrix problems.
- Interactive node highlighting, row/column indices, and visual state rendering for grid traversal algorithms.

### 5. 🔥 Developer Analytics & Daily Streak Counter
- Automated daily activity logging and streak counter to foster consistent coding habits.
- Local JSON persistence (`user_activity.json`) for code drafts, solved badges, run counts, and progress tracking.

### 6. 🎨 Glassmorphic Dark UI
- Built natively with SwiftUI using tailored dark modes, vibrant gradients, glowing focus rings, custom monospace code views, and responsive split-pane navigation.

---

## 🛠️ Tech Stack & Dependencies

| Layer | Technology | Description |
| :--- | :--- | :--- |
| **Framework** | SwiftUI | 100% native macOS user interface |
| **Language** | Swift 5.10+ | Modern Swift features, concurrency, and protocols |
| **Reactive Core**| Combine | State management, user activity streams, and event handlers |
| **Execution** | Local Subprocess / JSC | Fast, safe Swift evaluation engine |
| **Persistence** | FileSystem JSON | Offline local database for challenges, drafts, & streaks |

---

## 🏗️ App Architecture

SwiftForge follows a clean, decoupled **MVVM (Model-View-ViewModel)** architecture paired with modular Service Layers:

```
SwiftForge/
├── MyApp/
│   ├── ContentView.swift            # Root macOS Window & Split Layout
│   ├── ViewModels/
│   │   └── AppState.swift           # Central App State, Tabs & Streak Management
│   ├── Services/
│   │   ├── CodeRunnerService.swift  # Swift Code Execution & Evaluation Engine
│   │   ├── DatabaseService.swift    # Challenge Loader & JSON Storage
│   │   ├── UserActivityService.swift# Streak & Draft Code Saver
│   │   └── LoggerService.swift      # Console Logging & Error Diagnostics
│   ├── Models/
│   │   ├── Question.swift           # Question & Category Schema
│   │   ├── TestCase.swift           # Test Input, Expected & Actual Output
│   │   └── UserActivity.swift       # Daily History, Streaks, & Solved Set
│   ├── Views/
│   │   ├── SidebarView.swift        # Navigation Sidebar, Category Filters & Streaks
│   │   ├── CodeEditorView.swift     # Syntax Editor, Line Numbers & Font Control
│   │   ├── DSADescriptionView.swift # Markdown Problem Description & Hints
│   │   ├── DSATestCasesView.swift   # Test Cases Runner & Execution Results
│   │   ├── ConsoleView.swift        # Terminal Output & Log Console
│   │   ├── MatrixVisualizerView.swift # 2D Grid & Array Renderer
│   │   └── UIUtils.swift            # Design System, Buttons, Badges & Effects
│   └── Resources/
│       ├── questions.json           # Built-in Question Database
│       └── user_activity.json       # User Profile & Activity Storage
└── SwiftForge.xcodeproj             # Xcode Project Workspace
```

---

## 🚀 Getting Started

### Prerequisites
- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.0 or later
- **Swift Toolchain**: Swift 5.10+

### Installation & Setup

1. **Clone the Repository**
   ```bash
   git clone https://github.com/your-username/SwiftForge.git
   cd SwiftForge
   ```

2. **Open in Xcode**
   ```bash
   open SwiftForge.xcodeproj
   ```

3. **Build & Run**
   - Select `SwiftForge` target and select **My Mac** as target destination.
   - Press `Cmd + R` to build and launch the app.
   - Alternatively, execute the convenience script:
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
- **Binary Tree Max Depth**: Tree traversal (DFS/BFS).
- **Merge Sorted Arrays**: In-place array operations.
- **Matrix Rotation / Search**: Grid navigation with the integrated Matrix Visualizer.

### 🔹 Swift & iOS Practice Track
Master critical concepts required for iOS engineering roles:

- **Value vs. Reference Types**: Deep dive into `struct` vs `class` semantics, copy-on-write (COW), and performance implications.
- **ARC & Retain Cycles**: Identifying `weak` vs `unowned` references to fix memory leaks.
- **Concurrency & Actors**: `async`/`await`, Task Groups, Actor isolation, and thread safety.
- **Combine Framework**: `PassthroughSubject`, `CurrentValueSubject`, operator chaining, and error handling.
- **SwiftUI State & Binding**: Understanding `@State`, `@StateObject`, `@ObservedObject`, and `@EnvironmentObject`.

---

## 🎨 UI & Design System

SwiftForge is built with a custom **Modern Dark Glassmorphism Design System**:

- **Color Palette**: Ultra-dark slate backgrounds (`#0F1117`, `#181B24`), glowing electric blue (`#3B82F6`), cyan (`#06B6D4`), vibrant orange (`#F97316`), and emerald green (`#10B981`).
- **Typography**: System Monospaced font for code views, SF Pro Display for clean UI navigation.
- **Visual Feedback**: Real-time pass/fail glow indicators, animated activity streak fire icons, and pulse animations.

---

## 🤝 Contributing

Contributions are always welcome! If you'd like to add new DSA questions, Swift practice challenges, or UI visualizers:

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/NewChallenge`)
3. Commit your Changes (`git commit -m 'Add new Swift concurrency challenge'`)
4. Push to the Branch (`git checkout -b feature/NewChallenge`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

<div align="center">
  Crafted with ❤️ for the Swift & iOS Developer Community.
</div>
