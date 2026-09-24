# AI Agent System Setup Guide

## Overview
Two autonomous agents run on Supabase Edge Functions 24/7:
- **SEO/ASO Agent** — Finds link opportunities, audits content, drafts guest post pitches
- **Influencer Agent** — Finds influencers, analyzes fit, drafts outreach messages

Both run daily on a schedule. High-value opportunities are flagged for human approval before execution.

---

## 1. Database Setup

Apply the migration:
```bash
supabase migration up
```

Verify tables were created:
```bash
supabase db list  # Check for new tables
```

---

## 2. Environment Variables

Add these to your `.env.keys` file (or set in Supabase dashboard):

```bash
# Claude API
CLAUDE_API_KEY=sk-...

# Email Configuration (Namecheap SMTP)
NAMECHEAP_SMTP_HOST=mail.namecheap.com
NAMECHEAP_SMTP_PORT=587
NAMECHEAP_SMTP_USER=contact@outlayapp.net
NAMECHEAP_SMTP_PASSWORD=your_email_password
AGENT_EMAIL_FROM=contact@outlayapp.net

# Optional: For link research
HUNTER_API_KEY=...
AHREFS_API_KEY=...

# Agent Configuration
HIGH_VALUE_THRESHOLD=1000  # Flag opportunities worth >$1000
```

**For Supabase Edge Functions**, set these in:
1. Supabase Dashboard → Project → Settings → Edge Functions → Environment Variables
2. Or via CLI: `supabase secrets set CLAUDE_API_KEY=sk-...`

---

## 3. Deploy Edge Functions

```bash
# Deploy SEO/ASO Agent
supabase functions deploy seo_aso_agent

# Deploy Influencer Agent
supabase functions deploy influencer_agent

# Deploy Approval Handler
supabase functions deploy agent_approval_handler
```

Test locally first:
```bash
supabase functions serve seo_aso_agent
# In another terminal:
curl http://localhost:54321/functions/v1/seo_aso_agent
```

---

## 4. Schedule Cron Jobs

Add to `supabase/config.toml`:

```toml
# SEO/ASO Agent - Daily at 6 AM UTC
[[functions.seo_aso_agent]]
name = "seo_aso_agent"
enabled = true
cron_expression = "0 6 * * *"

# Influencer Agent - Daily at 8 AM UTC
[[functions.influencer_agent]]
name = "influencer_agent"
enabled = true
cron_expression = "0 8 * * *"
```

Or use Supabase Dashboard → Edge Functions → Cron Jobs

---

## 5. Using the Approval System

### Get Pending Approvals
```bash
curl https://your-project.supabase.co/functions/v1/agent_approval_handler
```

Returns:
```json
[
  {
    "id": "uuid",
    "agent_type": "influencer",
    "action_type": "send_outreach",
    "prospect_id": "uuid",
    "action_summary": "Send outreach to @username (tiktok, 150k followers, fit score: 8/10)",
    "approval_status": "pending",
    "created_at": "2026-09-25T10:00:00Z"
  }
]
```

### Approve an Action
```bash
curl -X POST https://your-project.supabase.co/functions/v1/agent_approval_handler \
  -H "Content-Type: application/json" \
  -d '{
    "approval_id": "uuid-from-pending-approvals",
    "action": "approve"
  }'
```

### Reject an Action
```bash
curl -X POST https://your-project.supabase.co/functions/v1/agent_approval_handler \
  -H "Content-Type: application/json" \
  -d '{
    "approval_id": "uuid-from-pending-approvals",
    "action": "reject"
  }'
```

---

## 6. Monitoring

### View Agent Logs
```sql
-- From Supabase SQL Editor
SELECT * FROM agent_logs ORDER BY run_date DESC LIMIT 20;
```

### View Link Opportunities
```sql
SELECT domain, outreach_status, relevance_score FROM link_opportunities
ORDER BY created_at DESC;
```

### View Influencer Prospects
```sql
SELECT platform, handle, engagement_rate, outreach_status FROM influencer_prospects
ORDER BY engagement_rate DESC;
```

---

## 7. Troubleshooting

### Agents not running?
1. Check Supabase logs: Dashboard → Edge Functions → Logs
2. Verify environment variables are set
3. Manually invoke: `supabase functions invoke seo_aso_agent`

### No emails sending?
- SMTP credentials may be wrong
- Check firewall/port 587 not blocked
- Update handler function to actually send emails (currently just logs)

### Claude API errors?
- Verify `CLAUDE_API_KEY` is set
- Check API key hasn't expired
- Monitor token usage

---

## 8. Next Steps

1. **Email Integration** — Update `seo_aso_agent` and approval handler to actually send emails via SMTP
2. **Influencer Research** — Connect to TikTok/Instagram APIs for better prospect data
3. **Revenue Tracking** — Link agent outreach to `influencer_codes` table for tracking
4. **Dashboard** — Create a web UI to manage approvals and view agent activity

---

## Cost Estimate

- **Claude API**: $5-15/month (depending on usage)
- **Supabase Pro**: Already included
- **Email**: $0 (using existing Namecheap account)
- **Total**: ~$5-15/month additional

---

## Security Notes

- All agents run server-side (no client exposure)
- Uses Supabase service role key (has full DB access)
- Email credentials stored in Supabase secrets
- Row-level security on agent tables (optional, currently service-role-only)
- No sensitive data logged in agent_logs


---

## ⚠️ FREE TIER CONSIDERATIONS

Since you're on Supabase **free tier**, here are some important notes:

### Edge Function Limits
- **Free tier**: ~50 invocations/month (agents may hit this)
- **Pro tier**: Unlimited invocations

### Recommendation
1. Deploy agents now on free tier to test
2. Run manually a few times to verify they work
3. Monitor usage for 1-2 weeks
4. Upgrade to Pro when you see value (agents finding opportunities daily)

### When Agents Hit Free Tier Limits
- Agents will fail to run after hitting limit
- You'll see errors in logs: "Free tier limit exceeded"
- Solution: Upgrade to Pro or reduce run frequency (run every 2-3 days instead of daily)

### Upgrade Path
When ready, upgrade from free → Pro:
1. Supabase Dashboard → Settings → Billing
2. Click "Upgrade to Pro"
3. Only pay for what you use beyond the free allowance
4. No downtime, takes effect immediately

---
