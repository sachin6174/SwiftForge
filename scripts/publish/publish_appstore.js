const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });

const APPLE_ID = process.env.APPLE_ID;
const APPLE_PASS = process.env.APPLE_PASS;

if (!APPLE_ID || !APPLE_PASS) {
  console.error('❌ Security Error: APPLE_ID and APPLE_PASS must be configured in your local .env file.');
  process.exit(1);
}
const APP_NAME = 'SwiftForge: DSA & iOS Studio';
const APP_SUBTITLE = 'DSA & iOS Engineering IDE';
const BUNDLE_ID = process.env.APP_IDENTIFIER || 'in.sachinserver.swiftforge';
const KEYWORDS = 'swift,dsa,leetcode,ios,developer,ide,algorithms,coding,interview,prep,swiftui,combine,macos';
const PROMO_TEXT = 'Master Swift Data Structures, Algorithms, and iOS Engineering offline on your Mac with real-time code runners and interactive visualizers!';
const PRIVACY_URL = 'https://sachinserver.in/swiftforge/privacy';
const SUPPORT_URL = 'https://sachinserver.in/swiftforge/support';
const MARKETING_URL = 'https://sachinserver.in/swiftforge';
const COPYRIGHT = '© 2026 Sachin Kumar. All rights reserved.';

const DESCRIPTION_PATH = path.join(__dirname, '../../fastlane/metadata/en-US/description.txt');
const DESCRIPTION = fs.existsSync(DESCRIPTION_PATH) 
  ? fs.readFileSync(DESCRIPTION_PATH, 'utf8') 
  : 'SwiftForge is the premier native macOS IDE for practicing Swift Data Structures, Algorithms, and iOS Architecture.';

async function runPublisher() {
  console.log('====================================================');
  console.log('🚀 Launching Playwright App Store Connect Publisher');
  console.log('====================================================');
  console.log(`👤 Apple ID: ${APPLE_ID}`);
  console.log(`🆔 Bundle ID: ${BUNDLE_ID}`);
  console.log('----------------------------------------------------');

  const browser = await chromium.launch({
    headless: false, // Opened visibly so user can see and enter 2FA if prompted
    slowMo: 300
  });

  const context = await browser.newContext({
    viewport: { width: 1280, height: 900 }
  });

  const page = await context.newPage();

  try {
    console.log('🌐 Navigating to App Store Connect...');
    await page.goto('https://appstoreconnect.apple.com', { waitUntil: 'networkidle' });

    // Step 1: Check for Apple ID Login Form / iFrame
    console.log('🔑 Performing Apple ID Login...');
    
    // Apple ID login page uses AID iframe
    await page.waitForTimeout(3000);
    const authFrame = page.frame({ url: /appleid\.apple\.com/ }) || page.mainFrame();

    const accountInput = await authFrame.waitForSelector('#account_name_text_field, input[type="email"], #account_name_text_field_label', { timeout: 15000 }).catch(() => null);
    
    if (accountInput) {
      console.log('  -> Filling Apple ID Email...');
      await accountInput.fill(APPLE_ID);
      await page.keyboard.press('Enter');
      await page.waitForTimeout(2000);
    }

    // Step 2: Fill Password
    const passwordInput = await authFrame.waitForSelector('#password_text_field, input[type="password"]', { timeout: 15000 }).catch(() => null);
    if (passwordInput) {
      console.log('  -> Filling Password...');
      await passwordInput.fill(APPLE_PASS);
      await page.keyboard.press('Enter');
      await page.waitForTimeout(4000);
    }

    // Step 3: Handle 2-Factor Authentication (2FA) if prompted
    console.log('📱 Checking 2-Factor Authentication state...');
    const is2FA = await page.evaluate(() => {
      return document.body.innerText.includes('Two-Factor Authentication') || 
             document.body.innerText.includes('verification code') ||
             document.querySelector('input[type="tel"]') !== null;
    }).catch(() => false);

    if (is2FA) {
      console.log('====================================================');
      console.log('⚠️  2-FACTOR AUTHENTICATION REQUIRED!');
      console.log('👉 Please check your trusted Apple Device or Phone.');
      console.log('👉 Type the 6-digit verification code directly into the opened browser window!');
      console.log('====================================================');
      
      // Wait for navigation after 2FA code is entered manually by user
      await page.waitForURL(/appstoreconnect\.apple\.com\/apps/, { timeout: 120000 }).catch(() => {
        console.log('⏳ Still waiting for 2FA completion...');
      });
    }

    // Step 4: Ensure App Store Connect Apps Page is open
    console.log('📦 Navigating to App Store Connect Apps Dashboard...');
    if (!page.url().includes('/apps')) {
      await page.goto('https://appstoreconnect.apple.com/apps', { waitUntil: 'networkidle' });
    }
    await page.waitForTimeout(3000);

    // Step 5: Search for SwiftForge App or Create New App
    console.log(`🔍 Searching for existing App Record: ${BUNDLE_ID}...`);
    const appFound = await page.isVisible(`text="${BUNDLE_ID}"`).catch(() => false);

    if (appFound) {
      console.log('✅ Found existing SwiftForge App Record! Clicking to open metadata page...');
      await page.click(`text="${BUNDLE_ID}"`);
    } else {
      console.log('➕ App record not found. Attempting to click "+" (New App)...');
      const addAppButton = await page.$('button:has-text("Add Apps"), button:has-text("New App"), [aria-label="Add Apps"], .ion-ios-add');
      if (addAppButton) {
        await addAppButton.click();
        await page.waitForTimeout(1000);
        const newAppMenuItem = await page.$('text="New App"');
        if (newAppMenuItem) await newAppMenuItem.click();
      }
    }

    await page.waitForTimeout(5000);

    console.log('====================================================');
    console.log('🎉 Automation Reached App Store Connect Dashboard!');
    console.log('   The browser window will remain open for inspection.');
    console.log('====================================================');

  } catch (err) {
    console.error('❌ Automation Notice:', err.message);
    console.log('👉 Browser window will stay open so you can continue manually if needed.');
  }
}

runPublisher();
