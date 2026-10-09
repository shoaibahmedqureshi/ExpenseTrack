-- Email outreach tracking table
CREATE TABLE IF NOT EXISTS influencer_outreach (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prospect_id uuid REFERENCES influencer_prospects(id) ON DELETE CASCADE,
  message_version integer DEFAULT 1,
  subject text NOT NULL,
  body text NOT NULL,
  status text DEFAULT 'draft', -- draft, pending_review, approved, sent, bounced, no_response, interested, rejected
  sent_date timestamp,
  response_date timestamp,
  response_text text,
  response_type text, -- interested, not_interested, no_response, ask_for_details
  email_opens integer DEFAULT 0,
  email_clicks integer DEFAULT 0,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

-- Create index for fast lookups
CREATE INDEX idx_influencer_outreach_prospect ON influencer_outreach(prospect_id);
CREATE INDEX idx_influencer_outreach_status ON influencer_outreach(status);
CREATE INDEX idx_influencer_outreach_sent_date ON influencer_outreach(sent_date);

-- Enable RLS
ALTER TABLE influencer_outreach ENABLE ROW LEVEL SECURITY;

CREATE POLICY "outreach_service_role_all" ON influencer_outreach
  FOR ALL USING (auth.role() = 'service_role');

-- Update influencer_prospects to add product_slug reference
ALTER TABLE influencer_prospects
ADD COLUMN IF NOT EXISTS product_slug text DEFAULT 'stitchify';

CREATE INDEX IF NOT EXISTS idx_influencer_prospects_product ON influencer_prospects(product_slug);
