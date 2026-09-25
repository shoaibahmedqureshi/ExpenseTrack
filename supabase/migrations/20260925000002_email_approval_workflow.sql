-- Email Drafts Table (for all agent-generated outreach)
CREATE TABLE IF NOT EXISTS email_drafts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_type text NOT NULL, -- 'influencer', 'seo_guest_post', 'tech_channel'
  recipient_name text NOT NULL,
  recipient_email text NOT NULL,
  recipient_platform text, -- 'instagram', 'tiktok', 'youtube', 'blog', etc.
  recipient_url text, -- link to their profile/site
  
  subject text NOT NULL,
  body text NOT NULL,
  
  status text DEFAULT 'pending_review', -- pending_review, approved, sent, rejected
  approval_notes text,
  approved_by text, -- your email when you approve
  approved_at timestamp,
  sent_at timestamp,
  
  sent_via text, -- 'smtp', 'manual', 'api'
  send_error text,
  
  metadata jsonb, -- context: fit_score, reason for contact, etc.
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  
  UNIQUE(agent_type, recipient_email, subject)
);

-- Email Logs (audit trail of what was sent)
CREATE TABLE IF NOT EXISTS email_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  draft_id uuid REFERENCES email_drafts(id),
  recipient_email text,
  subject text,
  sent_at timestamp DEFAULT now(),
  delivery_status text, -- 'queued', 'sent', 'bounced', 'failed'
  smtp_response text,
  notes text
);

-- Agent Approval Queue (high-value opportunities)
CREATE TABLE IF NOT EXISTS agent_approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_type text NOT NULL, -- 'influencer', 'seo'
  action_type text NOT NULL, -- 'send_email', 'publish_post', etc.
  prospect_id uuid,
  email_draft_id uuid REFERENCES email_drafts(id),
  
  action_summary text,
  priority text, -- 'high', 'medium', 'low'
  metadata jsonb, -- fit_score, engagement_rate, etc.
  
  approval_status text DEFAULT 'pending', -- pending, approved, rejected
  approved_at timestamp,
  approved_by text,
  approval_notes text,
  
  created_at timestamp DEFAULT now(),
  UNIQUE(agent_type, action_type, prospect_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_email_drafts_status ON email_drafts(status);
CREATE INDEX IF NOT EXISTS idx_email_drafts_recipient ON email_drafts(recipient_email);
CREATE INDEX IF NOT EXISTS idx_email_drafts_agent ON email_drafts(agent_type);
CREATE INDEX IF NOT EXISTS idx_email_drafts_created ON email_drafts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_approvals_status ON agent_approvals(approval_status);
CREATE INDEX IF NOT EXISTS idx_agent_approvals_created ON agent_approvals(created_at DESC);

-- RLS
ALTER TABLE email_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_approvals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "seo_tables_service_role" ON email_drafts FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "seo_tables_service_role" ON email_logs FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "seo_tables_service_role" ON agent_approvals FOR ALL USING (auth.role() = 'service_role');
