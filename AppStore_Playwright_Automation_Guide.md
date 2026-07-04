# 🤖 Playwright App Store Connect Automation Guide

This guide details how the automated Playwright browser script logs into **App Store Connect**, manages **2-Factor Authentication (2FA)**, and navigates the App Store publishing workflow for **SwiftForge**.

---

## 🔑 Configured Credentials Used

The script automatically pulls your credentials from your local [`.env`](file:///Users/sachinkumar/Desktop/Untitled%20Project/.env) file:

- **Apple ID**: Configured in `.env` (`APPLE_ID`)
- **Password**: Configured in `.env` (`APPLE_PASS`)
- **Bundle ID**: `in.sachinserver.swiftforge`
- **Team ID**: `M5Q7N9D29M`

---

## 🛠️ How it Handles 2-Factor Authentication (2FA)

Since Apple requires 2FA on web browser logins:
1. Playwright runs in **visible mode** (`headless: false`).
2. The script enters your email and password automatically.
3. When Apple displays the 6-digit 2FA prompt:
   - The script detects the prompt and logs a notification in your terminal.
   - You simply type the **6-digit code** sent to your iPhone/Mac directly into the opened browser window!
4. As soon as the 2FA code is entered, the script automatically resumes and opens **App Store Connect $\rightarrow$ Apps**.

---

## 🚀 How to Run the Script

### Option 1: Direct Node Execution
```bash
cd scripts/publish
npm start
```

### Option 2: Run via npx
```bash
cd scripts/publish
node publish_appstore.js
```

---

## 📂 Script Architecture

```
scripts/publish/
├── package.json          # Dependencies (playwright, dotenv)
└── publish_appstore.js   # Automated Playwright login & publishing workflow
```
