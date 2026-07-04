# 📝 What to Do Now — Registering Your App ID

Follow these exact steps to complete the screen currently open in your browser:

---

### Step 1: Fill in the Text Fields

1. **Description**:
   Type: `SwiftForge`

2. **Bundle ID**:
   - Ensure **Explicit** is selected (it is already selected).
   - In the text box under **Explicit**, paste:
     ```
     in.sachinserver.swiftforge
     ```

---

### Step 2: Enable Required Capabilities (Scroll Down)

Scroll down the list of **Capabilities** on that page and check the following checkboxes:

- [x] **App Groups** *(Used for local draft saving and user activity storage)*
- [x] **Hardened Runtime** *(Required for macOS App Store notarization)*

---

### Step 3: Complete Registration

1. Click the blue **Continue** button in the top-right corner.
2. Review the details on the next page.
3. Click **Register**.

---

### ✅ What I Have Already Updated for You

From your screenshot, I detected your Apple Developer Team ID: **`M5Q7N9D29M`**.

I have automatically updated the project files with your Team ID:
- Updated [`.env`](file:///Users/sachinkumar/Desktop/Untitled%20Project/.env) (`APPLE_TEAM_ID=M5Q7N9D29M`)
- Updated [`fastlane/Appfile`](file:///Users/sachinkumar/Desktop/Untitled%20Project/fastlane/Appfile) (`team_id("M5Q7N9D29M")`)
