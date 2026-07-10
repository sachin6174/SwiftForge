# 📋 SwiftForge — Master App Store Submission Checklist & Info Pack

This document contains **all the required information, text copy, metadata, legal documents, rating responses, and asset specifications** needed to publish **SwiftForge** to **App Store Connect**.

---

## 📌 1. Basic App Information

| App Store Field | Recommended Entry | Notes / Limits |
| :--- | :--- | :--- |
| **App Name** | `SwiftForge: DSA & iOS Studio` | Max 30 chars |
| **Subtitle** | `DSA & iOS Engineering IDE` | Max 30 chars |
| **Bundle ID** | `in.sachinserver.swiftforge` | Set in Xcode & App Store Connect |
| **Primary Category** | `Developer Tools` | |
| **Secondary Category**| `Education` | |
| **SKU** | `SWIFTFORGE_MAC_01` | Unique internal identifier |
| **Primary Language** | `English (U.S.)` | |
| **Price Tier** | `Free` (or desired price tier) | |
| **Copyright** | `© 2026 Sachin Kumar. All rights reserved.` | |

---

## 🔍 2. App Store Search & Marketing Metadata

### Keywords (100 char limit max)
```
swift,dsa,leetcode,ios,developer,ide,algorithms,coding,interview,prep,swiftui,combine,macos
```

### Promotional Text (170 char limit max)
```
Master Swift Data Structures, Algorithms, and iOS Engineering offline on your Mac with real-time code runners and interactive visualizers!
```

### Full Description
```
SwiftForge is the premier, native macOS IDE built specifically for iOS developers, Swift engineers, and computer science students preparing for senior technical interviews and honing algorithmic mastery.

Unlike web-based coding platforms, SwiftForge runs completely offline on your Mac. It provides instant code compilation, zero network latency, real-time assertions, and interactive data structure visualizers designed for pure Swift development.

FEATURES & HIGHLIGHTS

• DUAL PRACTICE TRACKS
Master LeetCode-style Data Structures & Algorithms (Arrays, Hash Maps, Linked Lists, Trees, Dynamic Programming, Graphs) alongside real-world iOS Engineering concepts (ARC & Retain Cycles, Swift Concurrency async/await, Combine Publishers, Value vs Reference types, and SwiftUI State).

• EMBEDDED SWIFT CODE EDITOR
Enjoy a high-performance syntax-highlighted code editor with line numbers, customizable font sizes, bracket auto-closing, and automatic local draft persistence so you never lose your progress.

• LOCAL EXECUTION ENGINE
Run Swift Code locally on your Mac using a safe subprocess pipeline. Experience immediate terminal console feedback, runtime error stack traces, execution duration (ms), and stdout logging.

• INTERACTIVE DATA STRUCTURE VISUALIZERS
Gain deep intuition for complex algorithms with dedicated visualizers:
- 2D Matrix & Grid Visualizer for grid search and DP problems.
- Array & Hash Table Visualizers highlighting target pairs and complement matching.
- Stack String Visualizers displaying character streams and stack balance metrics.
- Linked List Visualizers rendering node memory pointers.
- Staircase Height Visualizers illustrating dynamic programming recurrence relations.

• DEVELOPER ANALYTICS & DAILY STREAKS
Build a consistent daily coding habit with automated streak counters, solved challenge badges, run counts, and local JSON profile storage.

• SLEEK GLASSMORPHIC DARK DESIGN
Designed natively for macOS Sonoma & Sequoia with custom dark glassmorphic panels, glowing accent gradients, and fluid split-pane workspace views.

Boost your Swift and iOS engineering skills today with SwiftForge!
```

---

## ⚖️ 3. Legal & URLs

| Field | URL / Location | Status |
| :--- | :--- | :--- |
| **Privacy Policy URL** | `https://github.com/sachin6174/SwiftForge/blob/master/PRIVACY_POLICY.md` | Document at [`PRIVACY_POLICY.md`](file:///Users/sachinkumar/Desktop/SwiftForge/PRIVACY_POLICY.md) |
| **Terms of Use (EULA)** | `https://github.com/sachin6174/SwiftForge/blob/master/TERMS_OF_SERVICE.md` | Document at [`TERMS_OF_SERVICE.md`](file:///Users/sachinkumar/Desktop/SwiftForge/TERMS_OF_SERVICE.md) |
| **Support URL** | `https://github.com/sachin6174/SwiftForge/issues` | |
| **Marketing URL** | `https://github.com/sachin6174/SwiftForge` | |

---

## 📱 4. App Store Review Information

| Field | Required Value |
| :--- | :--- |
| **First Name** | `Sachin` |
| **Last Name** | `Kumar` |
| **Phone Number** | `+91 XXXXXXXXXX` |
| **Email Address** | `letslearngpt@gmail.com` |
| **Sign-in Required?** | `No` (App functions offline without user accounts) |
| **Reviewer Notes** | See [`fastlane/metadata/review_information/notes.txt`](file:///Users/sachinkumar/Desktop/Untitled%20Project/fastlane/metadata/review_information/notes.txt) |

---

## 🔞 5. Content Rating Questionnaire (Age Rating: 4+)

- **Violence**: None
- **Sexual Content**: None
- **Profanity / Crude Humor**: None
- **Alcohol, Tobacco, Drugs**: None
- **Gambling**: None
- **Unrestricted Web Access**: No
- **Personal Data Collection**: None
- **Calculated Rating**: **4+** (Suitable for all ages)

---

## 🎨 6. Required Media & Graphic Assets

### 1. App Icon
- **Format**: PNG, no transparency, 1024 x 1024 px.
- **Xcode Asset**: Located in `Assets.xcassets/AppIcon.appiconset`.

### 2. macOS App Screenshots (At least 1 required, up to 10 max)
- **Dimensions**: `1280 x 800 px`, `1440 x 900 px`, or `2880 x 1800 px` (16:10 aspect ratio PNG/JPEG).
- **Recommended Screenshots to Capture**:
  1. *Main Workspace*: DSA Practice Track showing Two Sum code editor & test results.
  2. *Interactive Visualizers*: Linked List Node Pointers and 2D Matrix Visualizer view.
  3. *Swift Practice Track*: Network URLSession GET request execution and live terminal logs.
  4. *Streaks & Analytics*: Activity history, daily streak counter, and solved problem badges.

---

## ⚡️ 7. Submission Step-by-Step

1. **Upload Binary**:
   ```bash
   ./release_app.sh
   ```
2. **Sync Metadata via Fastlane** (Optional):
   ```bash
   fastlane deliver
   ```
3. **App Store Connect Submission**:
   - Go to [App Store Connect](https://appstoreconnect.apple.com).
   - Select **SwiftForge** $\rightarrow$ **Mac App**.
   - Under **Build**, select the uploaded version (v1.0.0).
   - Click **Submit for Review**.
