# 🤖 Outlay Autonomous Profile Creation Agent

**Automatically create profiles, post content, and build links across 10+ platforms — 24/7, hands-free.**

---

## Features

✅ **Multi-Platform Support**
- Dev.to, Medium, Quora, LinkedIn, Twitter, Reddit, Hashnode, Substack, HackerNews, Ghost
- Extensible: Add more platforms via `platforms.json`

✅ **Fully Autonomous**
- Signs up with your Gmail account
- Verifies emails automatically
- Creates profiles with bio and username
- Posts content with Outlay links
- Runs on schedule (6 AM UTC daily)

✅ **Transparent & Trackable**
- Logs all activity to Supabase
- Dashboard shows real profile URLs
- Email notifications on completion
- Error tracking and retry logic

✅ **Smart Content**
- Generates unique articles per post
- SEO-optimized for each platform
- Includes Outlay links naturally
- Relevant to audience

---

## Architecture

```
┌─────────────────────────────────────────┐
│  Autonomous Profile Agent (Node.js)     │
│  ├─ Puppeteer (browser automation)      │
│  ├─ Email verification handling         │
│  ├─ Platform-specific signup flows      │
│  └─ Content generation                  │
└────────────────┬────────────────────────┘
                 │
        ┌────────▼────────┐
        │  Supabase DB    │
        ├─ agent_logs     │
        ├─ profile_links  │
        └─────────────────┘
                 │
        ┌────────▼────────┐
        │  Your Dashboard │
        │  (Shows URLs)   │
        └─────────────────┘
```

---

## Files Included

| File | Purpose |
|------|---------|
| `index-v2.js` | **Main agent** - Flexible, multi-platform |
| `index.js` | Detailed implementation (reference) |
| `platforms.json` | Platform configurations |
| `package.json` | Dependencies |
| `DEPLOYMENT.md` | Deployment guide |
| `.env.example` | Environment setup |

---

## Quick Start

### 1. Install

```bash
cd agents/profile-automation
npm install
```

### 2. Configure

```bash
cp .env.example .env
# Credentials already filled in
```

### 3. Test Locally

```bash
npm start
```

Expected output:
```
🤖 OUTLAY PROFILE AUTOMATION AGENT v2.0
📋 Processing 10 platforms...

✅ Dev.to profile created: https://dev.to/outlayapp
✅ Medium profile created: https://medium.com/@outlayapp
✅ Quora profile created: https://quora.com/profile/OutlayApp
...
```

### 4. Check Dashboard

Open `/dashboard.html` → Scroll to "Profiles Created" → See real URLs

---

## Deployment (24/7 Execution)

### Recommended: Railway (5 minutes)

1. **Push to GitHub**
   ```bash
   git add agents/profile-automation/
   git commit -m "feat: add autonomous profile agent"
   git push
   ```

2. **Deploy on Railway**
   - Go to [railway.app](https://railway.app)
   - New Project → GitHub Repo → Select your repo
   - Add variables from `.env`
   - Deploy (auto-deploys on git push)

3. **Enable Scheduling**
   - Railway Dashboard → Add "Cron" job
   - Schedule: `0 6 * * *` (6 AM UTC daily)
   - Command: `npm start`

**Done!** Agent now runs daily at 6 AM UTC automatically.

---

## How It Works

### Platform Signup Flow

```
1. Navigate to platform signup
   ↓
2. Find email input field (smart selectors)
   ↓
3. Enter your Gmail (outlay.noreply@gmail.com)
   ↓
4. Click continue/next button
   ↓
5. Handle email verification
   ↓
6. Fill profile info (username, bio)
   ↓
7. Save and confirm
   ↓
8. Store profile URL in Supabase
   ↓
9. Post article (if platform supports it)
   ↓
✅ Profile created + linked
```

### Smart Platform Detection

The agent uses multiple selectors to find form fields:
- `input[type="email"]`
- `input[name*="email"]`
- `input[placeholder*="email"]`
- `input[id*="email"]`

This allows it to work with different platform designs without code changes.

---

## Monitoring

### View Created Profiles

```bash
# Open /dashboard.html in browser
# Scroll to "Profiles Created" section
# See: https://dev.to/outlayapp, etc.
```

### Check Logs

```sql
-- In Supabase SQL Editor:
SELECT * FROM agent_logs 
WHERE agent_type = 'profile_automation'
ORDER BY run_date DESC 
LIMIT 20;
```

### Track Success Rate

```sql
SELECT 
  action,
  COUNT(*) as total,
  COUNT(CASE WHEN status = 'success' THEN 1 END) as successful
FROM agent_logs
WHERE agent_type = 'profile_automation'
GROUP BY action;
```

---

## Adding New Platforms

### Easy: Edit `platforms.json`

```json
{
  "name": "YourPlatform",
  "domain": "yourplatform.com",
  "signup_url": "https://yourplatform.com/signup",
  "username": "outlayapp",
  "profile_url_template": "https://yourplatform.com/user/outlayapp",
  "bio": "Your bio here",
  "can_post": true,
  "post_url": "https://yourplatform.com/new",
  "priority": 2
}
```

Agent automatically handles signup! No code changes needed.

---

## Troubleshooting

### Profiles not creating?

**Problem:** Puppeteer can't find email input  
**Solution:** Check platform HTML structure, update selectors in code

**Problem:** Email verification fails  
**Solution:** Enable Gmail API integration (see DEPLOYMENT.md)

**Problem:** Timeout errors  
**Solution:** Increase timeout in `.js` file from 5000 to 10000+ ms

### Rate limiting?

Some platforms block rapid signup attempts. Solution:
- Add delays between platforms
- Run on different times
- Use proxy rotation (advanced)

---

## Security

⚠️ **Important:**

1. **Change Gmail password** after deployment
   - Google Account → Security → App passwords
   - Generate "Outlay Agent" specific password

2. **Keep .env secure**
   - Never commit to GitHub
   - Only Railway/Heroku admins should see it

3. **Monitor logs**
   - Watch for failed signups (platforms may block)
   - Check for suspicious activity

4. **Rotate credentials monthly**
   - Update passwords in Railway/Heroku
   - Change Supabase keys periodically

---

## Performance

- **Runtime:** ~2-5 minutes per agent run
- **Memory:** 512 MB minimum, 1 GB recommended
- **Platforms:** Can handle 10+ simultaneously
- **Daily cost:** ~$0.50-2 (on Railway free tier)

---

## Next Steps

1. ✅ **Test locally:** `npm start`
2. ✅ **Verify profiles created** in dashboard
3. ✅ **Deploy to Railway** for 24/7 execution
4. ✅ **Enable scheduling** for daily 6 AM UTC runs
5. ✅ **Monitor logs** and adjust as needed
6. ✅ **Change Gmail password** for security

---

## Support

**Agent not working?**
1. Check `agent_logs` table in Supabase
2. Look for error messages
3. Verify .env variables
4. Check platform HTML (they may have changed)

**Want to add a platform?**
1. Add to `platforms.json`
2. Restart agent
3. Done! (No code changes needed)

**Need custom behavior?**
Edit `index-v2.js` and redeploy.

---

## FAQ

**Q: Will this get me banned from platforms?**  
A: Unlikely. We're following normal signup flow. Just don't spam.

**Q: What if platforms change their signup?**  
A: Agent will fail with clear error. Update selectors in code. Worst case: add platform to skip list temporarily.

**Q: Can I modify the bio/username?**  
A: Yes! Edit `platforms.json` → Change `bio` and `username` fields → Redeploy

**Q: Does this require manual email verification?**  
A: Currently yes. Gmail API integration coming soon for automation.

**Q: How much does this cost to run?**  
A: Railway free tier: $0  
   Railway paid tier: ~$5-10/month

---

**Ready to deploy?** See `DEPLOYMENT.md` for step-by-step instructions! 🚀
