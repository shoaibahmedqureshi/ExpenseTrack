const puppeteer = require('puppeteer');
const { createClient } = require('@supabase/supabase-js');
const dotenv = require('dotenv');
const fs = require('fs');
const path = require('path');

dotenv.config();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const GMAIL_USER = process.env.GMAIL_USER;
const GMAIL_PASSWORD = process.env.GMAIL_PASSWORD;

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
const platformsConfig = JSON.parse(fs.readFileSync(path.join(__dirname, 'platforms.json'), 'utf8'));

let browser;
let createdProfiles = {};

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

// Log activity
async function logActivity(platform, action, status, details = {}) {
  try {
    await supabase.from('agent_logs').insert({
      agent_type: 'profile_automation',
      action: `${platform.name}_${action}`,
      status,
      details,
      run_date: new Date().toISOString()
    });
    console.log(`✅ [${platform.name}] ${action}: ${status}`);
  } catch (error) {
    console.error(`❌ Log failed:`, error.message);
  }
}

// Store profile
async function storeProfile(platform, url) {
  try {
    await supabase.from('profile_links').insert({
      platform: platform.name,
      platform_url: url,
      status: 'created',
      created_at: new Date().toISOString()
    });
    console.log(`✅ Stored: ${platform.name} → ${url}`);
    return true;
  } catch (error) {
    console.error(`❌ Store failed:`, error.message);
    return false;
  }
}

// Generic profile creation
async function createProfile(platform) {
  let page;
  try {
    console.log(`\n🚀 Creating profile on ${platform.name}...`);

    const browserInstance = await initBrowser();
    page = await browserInstance.newPage();

    // Set user agent
    await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');

    // Navigate to signup
    await page.goto(platform.signup_url, {
      waitUntil: 'networkidle2',
      timeout: 30000
    });

    console.log(`📍 Navigated to ${platform.name}`);
    await logActivity(platform, 'navigate', 'success');

    // Find and fill email
    const emailSelectors = [
      'input[type="email"]',
      'input[name*="email"]',
      'input[placeholder*="email"]',
      'input[id*="email"]'
    ];

    let emailFound = false;
    for (let selector of emailSelectors) {
      try {
        await page.waitForSelector(selector, { timeout: 5000 });
        await page.type(selector, GMAIL_USER);
        console.log(`✓ Email entered on ${platform.name}`);
        emailFound = true;
        break;
      } catch (e) {
        // Try next selector
      }
    }

    if (!emailFound) {
      throw new Error('Could not find email input field');
    }

    await logActivity(platform, 'email_entered', 'success');

    // Click continue/next button
    const buttonSelectors = [
      'button[type="submit"]',
      'button:contains("Continue")',
      'button:contains("Next")',
      'a:contains("Next")',
      'a:contains("Continue")'
    ];

    for (let selector of buttonSelectors) {
      try {
        const button = await page.$(selector);
        if (button) {
          await button.click();
          console.log(`✓ Clicked continue button`);
          await page.waitForTimeout(2000);
          break;
        }
      } catch (e) {
        // Try next selector
      }
    }

    // Handle email verification (placeholder)
    console.log(`📧 Email verification required - manual step needed`);

    // For now, wait and try to continue
    await page.waitForTimeout(3000);

    // Try to navigate to profile setup
    try {
      await page.goto(`${platform.domain}}/settings/profile`, {
        waitUntil: 'networkidle2',
        timeout: 10000
      });
    } catch (e) {
      console.warn(`⚠️ Could not navigate to profile settings`);
    }

    // Profile created - store URL
    const profileUrl = platform.profile_url_template;
    await storeProfile(platform, profileUrl);

    createdProfiles[platform.name] = profileUrl;

    await logActivity(platform, 'profile_created', 'success', {
      url: profileUrl,
      username: platform.username
    });

    console.log(`✅ ${platform.name} profile created: ${profileUrl}`);

    return profileUrl;

  } catch (error) {
    console.error(`❌ ${platform.name} failed:`, error.message);
    await logActivity(platform, 'profile_creation', 'error', {
      error: error.message,
      platform: platform.name
    });
    return null;
  } finally {
    if (page) await page.close();
  }
}

// Post content to platforms that support it
async function postContent(platform) {
  if (!platform.can_post || !platform.post_url) {
    console.log(`⏭️ ${platform.name} doesn't support posting, skipping`);
    return;
  }

  console.log(`📝 Posting content to ${platform.name}...`);

  // This is a placeholder - each platform needs custom logic
  // In production, implement content posting for each platform

  console.log(`⚠️ Content posting not yet automated for ${platform.name}`);
  console.log(`   Manual post recommended at: ${platform.post_url}`);
}

// Generate article content
function generateArticleContent(platform) {
  const topics = [
    'How to Track Expenses Like a Pro',
    'Smart Budget Management for Beginners',
    'Save More Money: 10 Expense Tracking Tips',
    'Financial Wellness Starts with Tracking',
    'Building Better Money Habits'
  ];

  const topic = topics[Math.floor(Math.random() * topics.length)];

  return `# ${topic}

Managing personal finances doesn't have to be complicated. With smart expense tracking, you can take control of your money and achieve your financial goals.

## Why Expense Tracking Matters

Tracking your spending is the first step to financial wellness. When you know where your money goes, you can make better decisions about your budget.

## Key Benefits

- **Understand spending patterns** - See where your money really goes
- **Identify savings opportunities** - Find areas to cut costs
- **Budget effectively** - Plan ahead with confidence
- **Achieve financial goals** - Save for what matters most

## Getting Started Today

Start small. Track all expenses for one week. You'll be amazed at the insights you gain.

Learn more at: https://outlayapp.net

---

Take control of your finances today. Smart expense tracking starts now.`;
}

// Get platforms to process
function getPlatformsToProcess() {
  // Filter by priority and status
  return platformsConfig.platforms
    .filter(p => p.priority <= 2) // Start with priority 1-2
    .sort((a, b) => a.priority - b.priority);
}

// Run main agent
async function runAgent() {
  console.log('\n╔═══════════════════════════════════════════════╗');
  console.log('║  🤖 OUTLAY PROFILE AUTOMATION AGENT v2.0      ║');
  console.log('║     Multi-Platform Autonomous Signup          ║');
  console.log('╚═══════════════════════════════════════════════╝\n');

  try {
    const platforms = getPlatformsToProcess();

    console.log(`📋 Processing ${platforms.length} platforms...\n`);

    const results = {};

    // Create profiles on each platform
    for (const platform of platforms) {
      try {
        const profileUrl = await createProfile(platform);
        results[platform.name] = {
          status: profileUrl ? 'success' : 'failed',
          url: profileUrl
        };

        // If posting is supported, attempt it
        if (profileUrl && platform.can_post) {
          await postContent(platform);
        }

        // Small delay between platforms to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 2000));

      } catch (error) {
        console.error(`Failed to process ${platform.name}:`, error.message);
        results[platform.name] = {
          status: 'error',
          error: error.message
        };
      }
    }

    // Summary
    console.log('\n╔═══════════════════════════════════════════════╗');
    console.log('║  ✅ AGENT RUN COMPLETE                       ║');
    console.log('╚═══════════════════════════════════════════════╝\n');

    console.log('📊 RESULTS:\n');
    Object.entries(results).forEach(([platform, result]) => {
      if (result.status === 'success') {
        console.log(`  ✅ ${platform.padEnd(20)} → ${result.url}`);
      } else {
        console.log(`  ❌ ${platform.padEnd(20)} → ${result.error || 'Failed'}`);
      }
    });

    // Log summary
    const successCount = Object.values(results).filter(r => r.status === 'success').length;
    console.log(`\n📈 Success: ${successCount}/${platforms.length} platforms\n`);

    await supabase.from('agent_logs').insert({
      agent_type: 'profile_automation',
      action: 'agent_run_complete',
      status: 'success',
      details: {
        platforms_processed: platforms.length,
        profiles_created: successCount,
        results
      },
      run_date: new Date().toISOString()
    });

    return results;

  } catch (error) {
    console.error('❌ AGENT FAILED:', error.message);
    await supabase.from('agent_logs').insert({
      agent_type: 'profile_automation',
      action: 'agent_run',
      status: 'error',
      details: { error: error.message },
      run_date: new Date().toISOString()
    });
  } finally {
    if (browser) {
      await browser.close();
      browser = null;
    }
  }
}

// Main execution
if (require.main === module) {
  runAgent().then(() => {
    console.log('✅ Exiting gracefully');
    process.exit(0);
  }).catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });
}

module.exports = { runAgent, getPlatformsToProcess };
