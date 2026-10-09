-- ============================================================================
-- SEO/ASO AGENT TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS link_opportunities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  domain text NOT NULL,
  url text,
  domain_authority integer,
  relevance_score numeric,
  opportunity_type text,
  email text,
  contact_name text,
  outreach_status text DEFAULT 'discovered',
  notes text,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  UNIQUE(domain)
);

CREATE INDEX IF NOT EXISTS idx_link_opportunities_status ON link_opportunities(outreach_status);
CREATE INDEX IF NOT EXISTS idx_link_opportunities_domain ON link_opportunities(domain);

ALTER TABLE link_opportunities ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'link_opportunities' AND policyname = 'link_opportunities_service_role_all') THEN
    CREATE POLICY link_opportunities_service_role_all ON link_opportunities FOR ALL USING (auth.role() = 'service_role');
  END IF;
END $$;

-- ============================================================================

CREATE TABLE IF NOT EXISTS guest_post_pitches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  link_opportunity_id text,
  title text,
  content_brief text,
  pitch_text text,
  status text DEFAULT 'draft',
  sent_date timestamp,
  response_date timestamp,
  response_text text,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_guest_post_pitches_status ON guest_post_pitches(status);
CREATE INDEX IF NOT EXISTS idx_guest_post_pitches_link_id ON guest_post_pitches(link_opportunity_id);

ALTER TABLE guest_post_pitches ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'guest_post_pitches' AND policyname = 'guest_post_pitches_service_role_all') THEN
    CREATE POLICY guest_post_pitches_service_role_all ON guest_post_pitches FOR ALL USING (auth.role() = 'service_role');
  END IF;
END $$;

-- ============================================================================

CREATE TABLE IF NOT EXISTS content_audits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  app_domain text NOT NULL,
  audit_type text,
  findings jsonb,
  recommendations jsonb,
  priority text,
  status text DEFAULT 'pending',
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_content_audits_status ON content_audits(status);
CREATE INDEX IF NOT EXISTS idx_content_audits_app_domain ON content_audits(app_domain);

ALTER TABLE content_audits ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'content_audits' AND policyname = 'content_audits_service_role_all') THEN
    CREATE POLICY content_audits_service_role_all ON content_audits FOR ALL USING (auth.role() = 'service_role');
  END IF;
END $$;
