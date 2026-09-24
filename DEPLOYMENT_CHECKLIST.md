# 🚀 Deployment Checklist

Copy-paste ready commands to deploy your agents.

---

## ✅ Pre-Deployment Checklist

- [ ] Claude API key obtained from https://console.anthropic.com
- [ ] Namecheap email password / SMTP credentials ready
- [ ] Supabase CLI installed (`supabase --version`)
- [ ] In project directory (`cd /Users/saloomi/Documents/Expense\ Tracker`)

---

## 🔧 Step 1: Set Environment Variables

### Via Supabase Dashboard
1. Go to: https://supabase.com/dashboard
2. Select your Outlay project
3. Settings → Edge Functions → Secrets
4. Add each variable one by one:

```
CLAUDE_API_KEY
Value: sk-...your-key...
```

```
NAMECHEAP_SMTP_HOST
Value: mail.namecheap.com
```

```
NAMECHEAP_SMTP_PORT
Value: 587
```

```
NAMECHEAP_SMTP_USER
Value: contact@outlayapp.net
```

```
NAMECHEAP_SMTP_PASSWORD
Value: your_email_password
```

```
AGENT_EMAIL_FROM
Value: contact@outlayapp.net
```

```
HIGH_VALUE_THRESHOLD
Value: 1000
```

OR via CLI (one-liner):
```bash
supabase secrets set \
  CLAUDE_API_KEY=sk-... \
  NAMECHEAP_SMTP_HOST=mail.namecheap.com \
  NAMECHEAP_SMTP_PORT=587 \
  NAMECHEAP_SMTP_USER=contact@outlayapp.net \
  NAMECHEAP_SMTP_PASSWORD=your_password \
  AGENT_EMAIL_FROM=contact@outlayapp.net \
  HIGH_VALUE_THRESHOLD=1000
```

**Verify** (should show all keys):
```bash
supabase secrets list
```

---

## 📊 Step 2: Apply Database Migration

```bash
cd /Users/saloomi/Documents/Expense\ Tracker
supabase migration up
```

**Verify** (check for new tables):
```bash
supabase db pull  # Syncs local schema
# Should see 20260925000000_create_agent_tables listed
```

---

## 🎯 Step 3: Deploy Edge Functions

Deploy all three agents:
```bash
supabase functions deploy seo_aso_agent
supabase functions deploy influencer_agent
supabase functions deploy agent_approval_handler
```

**Output should say:**
```
✓ Function deployed successfully
  URL: https://xgavxbuezmivnseyhkye.supabase.co/functions/v1/seo_aso_agent
```

---

## 🧪 Step 4: Test Agents

### Test 1: Manual Invocation
```bash
supabase functions invoke seo_aso_agent
```

Expected output:
```json
{
  "status": "success",
  "opportunities_found": 3,
  "timestamp": "2026-09-25T10:00:00Z"
}
```

### Test 2: Check Logs
```bash
supabase functions logs seo_aso_agent
```

Should show agent starting + running + completing.

### Test 3: Verify Database Entries
```bash
supabase db execute "SELECT COUNT(*) FROM agent_logs;"
```

Should return: `1` (one log entry from your test)

### Test 4: View Discovered Opportunities
```bash
supabase db execute "SELECT domain, outreach_status FROM link_opportunities LIMIT 5;"
```

Should show discovered domains.

---

## ⏰ Step 5: Set Up Cron Jobs

### Option A: Via Supabase Dashboard
1. Go to: Project → Edge Functions
2. Click on `seo_aso_agent`
3. Cron expression: `0 6 * * *` (6 AM daily UTC)
4. Enable
5. Repeat for `influencer_agent` with `0 8 * * *`

### Option B: Via CLI (Edit config.toml)
```bash
# Edit the config
nano supabase/config.toml
```

Add this at the end:
```toml
[[functions.seo_aso_agent]]
name = "seo_aso_agent"
enabled = true
cron_expression = "0 6 * * *"

[[functions.influencer_agent]]
name = "influencer_agent"
enabled = true
cron_expression = "0 8 * * *"
```

Save (Ctrl+S, then Ctrl+X in nano)

Then push config:
```bash
supabase push
```

---

## ✨ Final Checks

After deployment, verify everything works:

```bash
# Check all functions deployed
supabase functions list

# Should show:
# seo_aso_agent
# influencer_agent
# agent_approval_handler
# apple-subscription-webhook (existing)
# google-subscription-webhook (existing)
# etc.
```

---

## 🎉 You're Live!

Agents will now run automatically:
- **6 AM UTC** — SEO agent runs, finds link opportunities
- **8 AM UTC** — Influencer agent runs, finds influencers

To check on agents:
```bash
# View latest logs
supabase functions logs seo_aso_agent

# Check database for results
supabase db execute "SELECT * FROM agent_logs ORDER BY run_date DESC LIMIT 5;"

# View discovered influencers
supabase db execute "SELECT handle, platform, engagement_rate FROM influencer_prospects LIMIT 10;"
```

---

## 📱 Next Steps

1. **Get pending approvals daily**:
   ```bash
   curl https://xgavxbuezmivnseyhkye.supabase.co/functions/v1/agent_approval_handler \
     -H "Authorization: Bearer $SUPABASE_KEY"
   ```

2. **Approve/Reject opportunities**:
   ```bash
   # Approve
   curl -X POST https://xgavxbuezmivnseyhkye.supabase.co/functions/v1/agent_approval_handler \
     -H "Content-Type: application/json" \
     -d '{"approval_id": "uuid", "action": "approve"}'
   ```

3. **Monitor dashboard**:
   - Check Supabase SQL Editor for `agent_logs`, `influencer_prospects`, `link_opportunities`
   - Set a daily reminder to review approvals

---

## ❌ Troubleshooting

### Agents not running?
```bash
# Check cron status
supabase functions list

# Check logs
supabase functions logs seo_aso_agent
supabase functions logs influencer_agent

# Try manual invocation
supabase functions invoke seo_aso_agent
```

### "Environment variable not found" error?
```bash
# Verify secrets are set
supabase secrets list

# If missing, set them:
supabase secrets set CLAUDE_API_KEY=sk-...
```

### "Database error" in logs?
```bash
# Verify migration applied
supabase db pull

# Check tables exist
supabase db execute "SELECT table_name FROM information_schema.tables WHERE table_schema='public';"
```

### Claude API errors?
- Verify API key correct
- Check token balance: https://console.anthropic.com/account/billing
- Verify model names in agents (`claude-3-5-haiku-20241022`)

---

## 📞 Support

- **Agent logs**: `supabase functions logs <function_name>`
- **Database issues**: `supabase db execute "query"`
- **General**: Check `AGENT_SETUP.md` or `AGENT_IMPLEMENTATION_SUMMARY.md`

---

## 🎯 Success Criteria

After 24 hours, you should have:
- ✅ `agent_logs` table with 2 entries (6 AM + 8 AM runs)
- ✅ `link_opportunities` table with 3-5 entries
- ✅ `influencer_prospects` table with 5-10 entries
- ✅ `guest_post_audits` table with audit results
- ✅ `agent_approvals` table with pending approvals

If you don't see these, check logs and re-run manually:
```bash
supabase functions invoke seo_aso_agent
supabase functions invoke influencer_agent
```

---

**Total setup time: 10-15 minutes**
**Ready? Let's deploy! 🚀**

---

## ⚠️ FREE TIER IMPORTANT NOTE

You're currently on Supabase **free tier**. This means:

### Edge Function Limits
- **Free tier**: ~50 monthly invocations total
- **Your agents**: 2 daily runs = ~60/month (may exceed limit)
- **Pro tier**: Unlimited invocations ($25/month)

### Strategy
**Option A (Recommended): Start on Free, Test, Then Upgrade**
1. Deploy agents as planned
2. Run manually 2-3 times to test
3. Monitor Edge Functions logs for 1-2 weeks
4. If agents are working + adding value → Upgrade to Pro
5. Once on Pro → Set up daily cron jobs

**Option B: Upgrade Immediately**
1. Upgrade to Pro now (Supabase Dashboard → Settings → Billing)
2. Deploy agents
3. Set up daily cron jobs
4. Agents run reliably every day

### What We Recommend
→ **Option A** — Test first, upgrade when you see value

### How to Monitor Usage
```bash
# Check Edge Functions invocation count
supabase functions list

# View logs to see invocation count
supabase functions logs seo_aso_agent
```

If you see "Quota exceeded" or similar errors → Time to upgrade to Pro.

---
