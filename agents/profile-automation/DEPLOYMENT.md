# Autonomous Profile Creation Agent - Deployment Guide

## Overview
This agent automatically creates profiles on Dev.to, Medium, and Quora, verifies emails, and posts articles with links to Outlay.

**Status:** Ready for deployment  
**Platforms:** Dev.to, Medium, Quora  
**Username:** outlayapp  
**Schedule:** Daily at 6 AM UTC

---

## Quick Start (Local Testing)

### 1. Install Dependencies
```bash
cd agents/profile-automation
npm install
```

### 2. Configure Environment
```bash
cp .env.example .env
# Edit .env with your credentials (already filled in)
```

### 3. Run Agent
```bash
npm start
```

This will immediately create profiles and post articles.

---

## Production Deployment (24/7 Execution)

### Option A: Railway (Recommended)

1. **Create Railway Account**
   - Go to [railway.app](https://railway.app)
   - Sign up with GitHub

2. **Deploy from GitHub**
   ```bash
   # Push this code to GitHub
   git add agents/profile-automation/
   git commit -m "feat: add autonomous profile creation agent"
   git push
   
   # In Railway dashboard:
   # 1. New Project → GitHub Repo
   # 2. Select your repo
   # 3. Add .env variables from .env.example
   # 4. Deploy
   ```

3. **Enable Scheduling**
   - In Railway, add a "Cron" plugin
   - Schedule: `0 6 * * *` (6 AM UTC daily)
   - Command: `npm start`

### Option B: Heroku (Free Alternative)

```bash
# Login to Heroku
heroku login

# Create app
heroku create outlay-profile-agent

# Add environment variables
heroku config:set SUPABASE_URL=https://xgavxbuezmivnseyhkye.supabase.co
heroku config:set SUPABASE_SERVICE_ROLE_KEY=<your_key>
heroku config:set GMAIL_USER=outlay.noreply@gmail.com
heroku config:set GMAIL_PASSWORD=Bhola@9585

# Deploy
git push heroku main

# Enable scheduler
heroku addons:create scheduler:standard

# In Heroku dashboard:
# Add job: npm start
# Frequency: Daily at 6 AM UTC
```

### Option C: AWS Lambda + EventBridge

1. **Prepare package**
   ```bash
   # Bundle app for Lambda
   zip -r lambda-deployment.zip . -x "node_modules/*"
   npm install --production
   zip -r lambda-deployment.zip node_modules/
   ```

2. **Create Lambda function**
   - Runtime: Node.js 18.x
   - Handler: `index.runAgent`
   - Timeout: 300 seconds
   - Memory: 1024 MB (Puppeteer needs this)

3. **Add environment variables** in Lambda

4. **Create EventBridge rule**
   - Schedule: `cron(0 6 * * ? *)` (6 AM UTC)
   - Target: Your Lambda function

---

## Monitoring & Logs

### View Agent Logs
```bash
# In Supabase dashboard:
# SQL Editor → Run query:

SELECT * FROM agent_logs 
WHERE agent_type = 'profile_automation'
ORDER BY run_date DESC
LIMIT 20;
```

### Check Created Profiles
```bash
# In Supabase dashboard:

SELECT * FROM profile_links 
WHERE platform IN ('Dev.to', 'Medium', 'Quora')
AND created_at > NOW() - INTERVAL '24 hours';
```

### Dashboard
- Open `/dashboard.html` in browser
- Scroll to "Profiles Created" section
- Should show real URLs:
  - https://dev.to/outlayapp
  - https://medium.com/@outlayapp
  - https://quora.com/profile/OutlayApp

---

## Troubleshooting

### Profiles not creating
- Check browser headless mode: Puppeteer may fail on some systems
- Solution: Install Chrome: `sudo apt-get install chromium-browser`
- Or use Puppeteer with system Chrome: `executablePath: '/usr/bin/chromium'`

### Email verification fails
- Gmail may block automated access
- Solution: Enable "Less secure app access" or use Gmail API
- Current: Uses placeholder, manual verification required

### Memory issues (Lambda)
- Puppeteer needs 1GB+
- Increase Lambda memory to 1536 MB or higher

### Timeout errors
- Increase timeout to 5+ minutes
- Platforms may have slow signup flows
- Consider running longer or in off-hours

---

## Security Notes

⚠️ **Before deploying:**

1. **Change Gmail password**
   - Since credentials are in code
   - Use app-specific password:
     - Google Account → Security → App passwords
     - Generate for "Outlay Agent"

2. **Rotate credentials regularly**
   - Update .env variables monthly
   - Regenerate service role key if needed

3. **Keep logs monitored**
   - Check Supabase logs daily
   - Watch for failed attempts (platform changes)

---

## Next Steps

1. ✅ **Local test:** Run `npm start` to verify profiles create
2. ⏳ **Deploy:** Choose Railway/Heroku/Lambda
3. 📊 **Monitor:** Check dashboard daily
4. 🔐 **Secure:** Change Gmail password after deployment
5. 📅 **Schedule:** Enable 6 AM UTC daily execution

---

## Support

If agent fails:
1. Check Supabase logs (`agent_logs` table)
2. Verify credentials are correct in .env
3. Check platform login requirements (they may have changed)
4. Increase Puppeteer timeouts if pages load slowly

For issues: Check logs in dashboard or Supabase SQL editor.
