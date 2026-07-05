# 🚀 SwiftForge — App Store Release & Automation Guide

This guide details the complete process for building, signing, and releasing **SwiftForge** to **App Store Connect**, **TestFlight**, and the **Mac App Store** using CLI scripts, Fastlane, and GitHub Actions CI/CD.

---

## 📋 Table of Contents
- [1. Prerequisites](#1-prerequisites)
- [2. App Store Connect API Key Setup](#2-app-store-connect-api-key-setup)
- [3. Local CLI Build & Release](#3-local-cli-build--release)
- [4. Fastlane Release Commands](#4-fastlane-release-commands)
- [5. GitHub Actions CI/CD Setup](#5-github-actions-cicd-setup)
- [6. TestFlight & Production Submission](#6-testflight--production-submission)

---

## 1. Prerequisites

Before releasing to the Mac App Store, ensure you have:
1. **Apple Developer Program Membership** (Individual or Organization account).
2. **Mac App Store Distribution Certificate** & **App Store Provisioning Profile**.
22. **App Store Connect App Record Setup**:
   - Go to [App Store Connect > Apps](https://appstoreconnect.apple.com/apps) and click **+ New App**.
   - Fill in the required fields as follows:

| Field | Value | Description |
| :--- | :--- | :--- |
| **Platforms** | ✅ `iOS`, ✅ `macOS` | Enable both iOS and macOS support |
| **Name** | `SwiftForge` | Public App Store name |
| **Primary Language** | `English (U.S.)` | Default store localization |
| **Bundle ID** | `SwiftForge - in.sachinserver.swiftforge` | Registered App ID |
| **SKU** | `SWIFTFORGE-2026-001` | Internal unique tracking ID |
| **User Access** | `Full Access` | Developer team access level |

24. **Fastlane installed on your Mac**:
   ```bash
   brew install fastlane
   # or
   sudo gem install fastlane
   ```

---

## 2. App Store Connect API Key Setup

Using App Store Connect API Keys allows 100% automated uploads without requiring 2-Factor Authentication (2FA) prompts.

1. Go to [App Store Connect > Users and Access > Keys](https://appstoreconnect.apple.com/access/api).
2. Click **+** to generate a new key:
   - Name: `SwiftForge Release Key`
   - Access: **App Manager** or **Admin**
3. Note the following values:
   - **Key ID**: e.g., `A1B2C3D4E5`
   - **Issuer ID**: e.g., `69a670ef-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
   - Download the `.p8` private key file (e.g., `AuthKey_A1B2C3D4E5.p8`).

---

## 3. Local CLI Build & Release

We have included a automated release script `release_app.sh`.

### To build and archive locally:
```bash
chmod +x release_app.sh
./release_app.sh
```

This script performs:
1. Cleans previous builds in `./build/`.
2. Archives the Xcode project into `./build/SwiftForge.xcarchive`.
3. Exports an App Store ready distribution package (`.pkg`) using `ExportOptions.plist`.
4. Triggers Fastlane upload if configured.

---

## 4. Fastlane Release Commands

Fastlane is pre-configured in `fastlane/Fastfile` and `fastlane/Appfile`.

### Commands:

#### Build `.pkg` locally without uploading:
```bash
fastlane mac build_pkg
```

#### Full Build, Sign & Upload to App Store Connect / TestFlight:
```bash
export APP_STORE_CONNECT_API_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
export APPLE_ID="your-email@example.com"
export APPLE_TEAM_ID="YOUR_TEAM_ID"

fastlane mac release
```

---

## 5. GitHub Actions CI/CD Setup

Automated release workflow is configured in `.github/workflows/deploy.yml`.

### Required GitHub Secrets:
Navigate to **GitHub Repository > Settings > Secrets and variables > Actions** and add:

| Secret Name | Description |
| :--- | :--- |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID from App Store Connect |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID UUID from App Store Connect |
| `APP_STORE_CONNECT_API_KEY_KEY` | Contents of `.p8` key file |
| `APPLE_ID` | Apple Developer email |
| `APPLE_TEAM_ID` | 10-character Apple Developer Team ID |
| `BUILD_CERTIFICATE_BASE64` | Base64 encoded Mac App Distribution `.p12` cert |
| `P12_PASSWORD` | Password for `.p12` certificate |
| `KEYCHAIN_PASSWORD` | Random temporary password for CI keychain |

### How to Trigger CI/CD Release:
Simply tag a new version commit and push to GitHub:
```bash
git tag v1.0.0
git push origin v1.0.0
```
*GitHub Actions will automatically build, sign, upload `.pkg` to App Store Connect, and create a GitHub Release with the build artifact!*

---

## 6. TestFlight & Production Submission

Once uploaded:
1. Log into [App Store Connect](https://appstoreconnect.apple.com).
2. Go to **TestFlight** tab to add internal & external beta testers.
3. When ready for store release, select the build in **App Store > Build**, add screenshots/description, and submit for **App Review**.
