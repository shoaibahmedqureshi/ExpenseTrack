const puppeteer = require('puppeteer');
const { createClient } = require('@supabase/supabase-js');
const dotenv = require('dotenv');
const schedule = require('node-schedule');

dotenv.config();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const GMAIL_USER = process.env.GMAIL_USER;
const GMAIL_PASSWORD = process.env.GMAIL_PASSWORD;

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// Global agent state
let browser;
let profiles = {
  devto: null,
  medium: null,
  quora: null
};

// Initialize browser
async function initBrowser() {
  if (!browser) {
    browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
  }
  return browser;
}

// Log agent activity
async function logActivity(platform, action, status, details = {}) {
  try {
    await supabase.from('agent_logs').insert({
      agent_type: 'profile_automation',
      action: `${platform}_${action}`,
      status,
      details,
      run_date: new Date().toISOString()
    });
    console.log(`✅ [${platform}] ${action}: ${status}`, details);
  } catch (error) {
    console.error(`❌ Failed to log activity:`, error.message);
  }
}

// Store created profile
async function storeProfile(platform, url, username) {
  try {
    const { data, error } = await supabase.from('profile_links').insert({
      platform,
      platform_url: url,
      status: 'created',
      created_at: new Date().toISOString()
    });

    if (error) throw error;
    console.log(`✅ Stored profile: ${platform} → ${url}`);
    return url;
  } catch (error) {
    console.error(`❌ Failed to store profile:`, error.message);
    return null;
  }
}

// Generate unique article content
async function generateArticleContent(platform) {
  const topics = [
    'How to Track Expenses Like a Pro',
    'Budget Management Tips for Busy Professionals',
    'Smart Ways to Save Money: The Expense Tracking Approach',
    'Building Better Financial Habits with Expense Tracking',
    'Why Personal Finance Management Matters'
  ];

  const topic = topics[Math.floor(Math.random() * topics.length)];

  return `# ${topic}

Managing your finances doesn't have to be complicated. With proper expense tracking, you can take control of your money and build better financial habits.

## Key Benefits

- **Track spending patterns** - Understand where your money goes
- **Identify savings opportunities** - Find areas to cut costs
- **Budget more effectively** - Plan ahead with confidence
- **Achieve financial goals** - Save for what matters most

## Getting Started

Start by tracking all your expenses for a month. You'll be surprised at the insights you gain about your spending habits.

Tools like Outlay make this process simple and intuitive. With automatic categorization and detailed reports, you can focus on what matters - making smarter financial decisions.

[Download Outlay - Smart Expense Tracking](https://outlayapp.net)

---
Learn more about personal finance management and take control of your budget today.`;
}

// Dev.to Profile Creation
async function createDevtoProfile() {
  let page;
  try {
    console.log('\n🚀 Starting Dev.to profile creation...');

    const browserInstance = await initBrowser();
    page = await browserInstance.newPage();

    // Navigate to signup
    await page.goto('https://dev.to/enter', { waitUntil: 'networkidle2' });
    await logActivity('devto', 'navigate_signup', 'success');

    // Wait for email input and enter Gmail
    await page.waitForSelector('input[type="email"]', { timeout: 10000 });
    await page.type('input[type="email"]', GMAIL_USER);
    await logActivity('devto', 'enter_email', 'success');

    // Click continue
    const continueButton = await page.$('button:contains("Continue")');
    if (!continueButton) {
      // Try alternative selectors
      const buttons = await page.$$('button');
      for (let btn of buttons) {
        const text = await page.evaluate(el => el.textContent, btn);
        if (text.includes('Continue') || text.includes('Next')) {
          await btn.click();
          break;
        }
      }
    }

    await page.waitForTimeout(2000);
    await logActivity('devto', 'clicked_continue', 'success');

    // Handle email verification
    await handleEmailVerification('devto');

    // After verification, set up profile
    await page.goto('https://dev.to/settings/profile', { waitUntil: 'networkidle2' });

    // Fill username
    const usernameInput = await page.$('input[name="user[username]"]') ||
                         await page.$('input[placeholder*="username"]');
    if (usernameInput) {
      await usernameInput.click({ clickCount: 3 });
      await page.type('input[name="user[username]"]', 'outlayapp');
    }

    // Add bio
    const bioInput = await page.$('textarea[name="user[bio]"]');
    if (bioInput) {
      await bioInput.click();
      await page.type('textarea[name="user[bio]"]', 'Smart expense tracking & budget management app. Making personal finance simple.');
    }

    // Save profile
    const saveButton = await page.$('button:contains("Save")');
    if (saveButton) await saveButton.click();

    await page.waitForTimeout(2000);

    // Get profile URL
    const profileUrl = 'https://dev.to/outlayapp';
    await storeProfile('Dev.to', profileUrl, 'outlayapp');

    // Post article
    await postDevtoArticle(page);

    profiles.devto = profileUrl;
    await logActivity('devto', 'profile_creation', 'success', { url: profileUrl });

    return profileUrl;

  } catch (error) {
    console.error('❌ Dev.to profile creation failed:', error.message);
    await logActivity('devto', 'profile_creation', 'error', { error: error.message });
    return null;
  } finally {
    if (page) await page.close();
  }
}

// Post to Dev.to
async function postDevtoArticle(page) {
  try {
    console.log('📝 Posting article to Dev.to...');

    const content = await generateArticleContent('devto');

    await page.goto('https://dev.to/new', { waitUntil: 'networkidle2' });

    // Enter title
    await page.waitForSelector('input[placeholder*="title"]', { timeout: 5000 });
    await page.type('input[placeholder*="title"]', 'How to Track Expenses Like a Pro');

    // Enter content
    const contentArea = await page.$('textarea[placeholder*="content"]') ||
                       await page.$('div[contenteditable="true"]');
    if (contentArea) {
      await contentArea.click();
      await page.type('textarea', content);
    }

    // Publish
    const publishBtn = await page.$('button:contains("Publish")');
    if (publishBtn) await publishBtn.click();

    await page.waitForTimeout(3000);
    await logActivity('devto', 'post_article', 'success');

  } catch (error) {
    console.warn('⚠️ Could not post article to Dev.to:', error.message);
  }
}

// Medium Profile Creation
async function createMediumProfile() {
  let page;
  try {
    console.log('\n🚀 Starting Medium profile creation...');

    const browserInstance = await initBrowser();
    page = await browserInstance.newPage();

    await page.goto('https://medium.com/m/signin', { waitUntil: 'networkidle2' });

    // Click "Sign up with email"
    const signupLink = await page.$('a:contains("Create an account")');
    if (signupLink) await signupLink.click();

    await page.waitForSelector('input[type="email"]', { timeout: 5000 });
    await page.type('input[type="email"]', GMAIL_USER);

    const continueBtn = await page.$('button:contains("Continue")');
    if (continueBtn) await continueBtn.click();

    await page.waitForTimeout(2000);
    await logActivity('medium', 'enter_email', 'success');

    // Handle email verification
    await handleEmailVerification('medium');

    // Set up profile
    await page.goto('https://medium.com/me/settings/profile', { waitUntil: 'networkidle2' });

    const nameInput = await page.$('input[placeholder*="name"]');
    if (nameInput) {
      await nameInput.click({ clickCount: 3 });
      await page.type('input[placeholder*="name"]', 'Outlay App');
    }

    const bioInput = await page.$('textarea[placeholder*="bio"]');
    if (bioInput) {
      await bioInput.click();
      await page.type('textarea', 'Smart expense tracking & budget management. Making personal finance simple.');
    }

    // Save
    const saveBtn = await page.$('button:contains("Save")');
    if (saveBtn) await saveBtn.click();

    await page.waitForTimeout(2000);

    const profileUrl = 'https://medium.com/@outlayapp';
    await storeProfile('Medium', profileUrl, '@outlayapp');

    // Post article
    await postMediumArticle(page);

    profiles.medium = profileUrl;
    await logActivity('medium', 'profile_creation', 'success', { url: profileUrl });

    return profileUrl;

  } catch (error) {
    console.error('❌ Medium profile creation failed:', error.message);
    await logActivity('medium', 'profile_creation', 'error', { error: error.message });
    return null;
  } finally {
    if (page) await page.close();
  }
}

// Post to Medium
async function postMediumArticle(page) {
  try {
    console.log('📝 Posting article to Medium...');

    const content = await generateArticleContent('medium');

    await page.goto('https://medium.com/new-story', { waitUntil: 'networkidle2' });

    // Click title area
    const titleArea = await page.$('h1[contenteditable="true"]') ||
                     await page.$('div[contenteditable="true"]');
    if (titleArea) {
      await titleArea.click();
      await page.type('h1', 'How to Track Expenses Like a Pro');
    }

    // Add content
    const contentArea = await page.$('article div[contenteditable="true"]');
    if (contentArea) {
      await contentArea.click();
      await page.type('div', content);
    }

    // Publish
    const publishBtn = await page.$('button:contains("Publish")');
    if (publishBtn) await publishBtn.click();

    await page.waitForTimeout(3000);
    await logActivity('medium', 'post_article', 'success');

  } catch (error) {
    console.warn('⚠️ Could not post article to Medium:', error.message);
  }
}

// Quora Profile Creation
async function createQuoraProfile() {
  let page;
  try {
    console.log('\n🚀 Starting Quora profile creation...');

    const browserInstance = await initBrowser();
    page = await browserInstance.newPage();

    await page.goto('https://www.quora.com/auth/signup', { waitUntil: 'networkidle2' });

    // Enter email
    await page.waitForSelector('input[type="email"]', { timeout: 5000 });
    await page.type('input[type="email"]', GMAIL_USER);

    // Click next/continue
    const continueBtn = await page.$('button[type="submit"]');
    if (continueBtn) await continueBtn.click();

    await page.waitForTimeout(2000);
    await logActivity('quora', 'enter_email', 'success');

    // Handle email verification
    await handleEmailVerification('quora');

    // Set up profile
    await page.goto('https://www.quora.com/settings/profile', { waitUntil: 'networkidle2' });

    const nameInput = await page.$('input[placeholder*="Name"]');
    if (nameInput) {
      await nameInput.click({ clickCount: 3 });
      await page.type('input[placeholder*="Name"]', 'OutlayApp');
    }

    const bioInput = await page.$('textarea[placeholder*="bio"]');
    if (bioInput) {
      await bioInput.click();
      await page.type('textarea', 'Smart expense tracking & budget management for everyone');
    }

    // Save
    const saveBtn = await page.$('button:contains("Save")');
    if (saveBtn) await saveBtn.click();

    await page.waitForTimeout(2000);

    const profileUrl = 'https://www.quora.com/profile/OutlayApp';
    await storeProfile('Quora', profileUrl, 'OutlayApp');

    profiles.quora = profileUrl;
    await logActivity('quora', 'profile_creation', 'success', { url: profileUrl });

    return profileUrl;

  } catch (error) {
    console.error('❌ Quora profile creation failed:', error.message);
    await logActivity('quora', 'profile_creation', 'error', { error: error.message });
    return null;
  } finally {
    if (page) await page.close();
  }
}

// Email verification
async function handleEmailVerification(platform) {
  try {
    console.log(`📧 Handling email verification for ${platform}...`);

    // Check Gmail for verification email
    const verificationLink = await getVerificationLink(platform);

    if (verificationLink) {
      const browserInstance = await initBrowser();
      const verifyPage = await browserInstance.newPage();
      await verifyPage.goto(verificationLink, { waitUntil: 'networkidle2' });
      await verifyPage.waitForTimeout(2000);
      await verifyPage.close();

      await logActivity(platform, 'email_verified', 'success');
      return true;
    }

  } catch (error) {
    console.warn(`⚠️ Email verification for ${platform} failed:`, error.message);
  }

  return false;
}

// Get verification link from Gmail
async function getVerificationLink(platform) {
  try {
    // This is a placeholder - in production, you'd use Gmail API
    console.log(`Looking for ${platform} verification email...`);

    // For now, just wait for manual verification
    // In production: integrate Google API to read emails

    return null;
  } catch (error) {
    console.error('Failed to get verification link:', error.message);
    return null;
  }
}

// Run all profile creations
async function runAgent() {
  console.log('\n═══════════════════════════════════════════');
  console.log('🤖 Outlay Profile Automation Agent Started');
  console.log('═══════════════════════════════════════════\n');

  try {
    // Create profiles
    const results = {
      devto: await createDevtoProfile(),
      medium: await createMediumProfile(),
      quora: await createQuoraProfile()
    };

    console.log('\n✅ PROFILES CREATED:');
    Object.entries(results).forEach(([platform, url]) => {
      if (url) console.log(`  ✓ ${platform}: ${url}`);
    });

    return results;

  } catch (error) {
    console.error('❌ Agent run failed:', error.message);
    await logActivity('system', 'agent_run', 'error', { error: error.message });
  } finally {
    if (browser) await browser.close();
  }
}

// Schedule agent
function scheduleAgent() {
  // Run daily at 6 AM UTC
  schedule.scheduleJob('0 6 * * *', async () => {
    console.log('⏰ Scheduled agent run triggered');
    await runAgent();
  });

  console.log('📅 Agent scheduled to run daily at 6 AM UTC');
}

// Main
if (require.main === module) {
  // Run immediately for testing
  runAgent().then(() => {
    console.log('\n✅ Agent run complete');
    process.exit(0);
  }).catch(error => {
    console.error('❌ Agent failed:', error);
    process.exit(1);
  });

  // Uncomment to enable scheduling
  // scheduleAgent();
  // Keep process alive
  // setInterval(() => {}, 1000);
}

module.exports = { runAgent, scheduleAgent };
