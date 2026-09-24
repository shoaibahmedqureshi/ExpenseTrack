-- Agent System Tables for SEO/ASO and Influencer Outreach

-- SEO/ASO Agent Tables

CREATE TABLE IF NOT EXISTS link_opportunities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  domain text NOT NULL,
  url text NOT NULL,
  domain_authority integer,
  relevance_score float,
  outreach_status text DEFAULT 'discovered', -- discovered, pitching, accepted, rejected
  email text,
  contact_name text,
  pitch_version integer DEFAULT 0,
  subscription_offered text, -- expense_tracker_pro_annual, etc.
  subscription_code text, -- generated promo code
  notes text,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  UNIQUE(domain, url)
);

CREATE TABLE IF NOT EXISTS guest_post_audits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  app_domain text NOT NULL, -- outlayapp.net, technologistan.pk, etc.
  audit_type text, -- seo, content, technical, aso
  findings jsonb, -- structured audit results
  recommendations jsonb, -- suggested fixes
  priority text, -- critical, high, medium, low
  status text DEFAULT 'pending', -- pending, in_progress, completed
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS guest_post_pitches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  link_opportunity_id uuid REFERENCES link_opportunities(id) ON DELETE CASCADE,
  title text,
  content_brief text,
  pitch_text text,
  status text DEFAULT 'draft', -- draft, sent, interested, rejected
  sent_date timestamp,
  response_date timestamp,
  response_text text,
  created_at timestamp DEFAULT now()
);

-- Influencer Agent Tables

CREATE TABLE IF NOT EXISTS influencer_prospects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  platform text NOT NULL, -- instagram, tiktok, youtube
  handle text NOT NULL,
  follower_count integer,
  engagement_rate float,
  audience_demographics jsonb,
  niche text, -- personal_finance, expense_tracking, budgeting, etc.
  outreach_status text DEFAULT 'discovered', -- discovered, contacted, responded, negotiating, onboarded, rejected
  email text,
  contact_method text, -- email, dm, other
  discovered_date timestamp DEFAULT now(),
  first_contact_date timestamp,
  notes text,
  created_at timestamp DEFAULT now(),
  UNIQUE(platform, handle)
);

CREATE TABLE IF NOT EXISTS influencer_outreach (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prospect_id uuid REFERENCES influencer_prospects(id) ON DELETE CASCADE,
  message_version integer DEFAULT 1,
  subject text,
  body text,
  sent_date timestamp,
  response_date timestamp,
  response_text text,
  response_type text, -- interested, not_interested, no_response, ask_for_details
  created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS influencer_onboarding (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prospect_id uuid REFERENCES influencer_prospects(id) ON DELETE CASCADE,
  status text DEFAULT 'pending', -- pending, contract_sent, contract_signed, live, paused
  contract_url text,
  deal_terms jsonb, -- {revenue_share: 20, minimum_engagement: ..., contract_start: ..., end_date: ...}
  payment_method text,
  payment_email text,
  first_promotion_date timestamp,
  revenue_ytd float DEFAULT 0,
  updated_at timestamp DEFAULT now(),
  created_at timestamp DEFAULT now()
);

-- Agent Management Tables

CREATE TABLE IF NOT EXISTS agent_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_type text NOT NULL, -- seo_aso, influencer
  action text,
  status text, -- success, error, pending
  details jsonb,
  error_message text,
  run_date timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS agent_approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_type text NOT NULL,
  action_type text, -- send_email, sign_contract, payment_approval
  prospect_id uuid,
  link_opportunity_id uuid,
  action_summary text,
  approval_status text DEFAULT 'pending', -- pending, approved, rejected
  approved_by text,
  approved_date timestamp,
  executed_date timestamp,
  created_at timestamp DEFAULT now()
);

-- Indexes for performance

CREATE INDEX IF NOT EXISTS idx_link_opportunities_status ON link_opportunities(outreach_status);
CREATE INDEX IF NOT EXISTS idx_link_opportunities_domain ON link_opportunities(domain);
CREATE INDEX IF NOT EXISTS idx_guest_post_audits_domain ON guest_post_audits(app_domain);
CREATE INDEX IF NOT EXISTS idx_influencer_prospects_platform ON influencer_prospects(platform);
CREATE INDEX IF NOT EXISTS idx_influencer_prospects_status ON influencer_prospects(outreach_status);
CREATE INDEX IF NOT EXISTS idx_influencer_onboarding_status ON influencer_onboarding(status);
CREATE INDEX IF NOT EXISTS idx_agent_logs_type ON agent_logs(agent_type);
CREATE INDEX IF NOT EXISTS idx_agent_logs_run_date ON agent_logs(run_date);
CREATE INDEX IF NOT EXISTS idx_agent_approvals_status ON agent_approvals(approval_status);
CREATE INDEX IF NOT EXISTS idx_agent_approvals_type ON agent_approvals(agent_type);

-- Enable RLS on agent tables

ALTER TABLE link_opportunities ENABLE ROW LEVEL SECURITY;
ALTER TABLE guest_post_audits ENABLE ROW LEVEL SECURITY;
ALTER TABLE guest_post_pitches ENABLE ROW LEVEL SECURITY;
ALTER TABLE influencer_prospects ENABLE ROW LEVEL SECURITY;
ALTER TABLE influencer_outreach ENABLE ROW LEVEL SECURITY;
ALTER TABLE influencer_onboarding ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_approvals ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Service role has full access via edge functions

CREATE POLICY "agent_tables_service_role_all" ON link_opportunities
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "agent_tables_service_role_all" ON guest_post_audits
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "agent_tables_service_role_all" ON guest_post_pitches
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "agent_tables_service_role_all" ON influencer_prospects
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "agent_tables_service_role_all" ON influencer_outreach
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "agent_tables_service_role_all" ON influencer_onboarding
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "agent_tables_service_role_all" ON agent_logs
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "agent_tables_service_role_all" ON agent_approvals
  FOR ALL USING (auth.role() = 'service_role');
