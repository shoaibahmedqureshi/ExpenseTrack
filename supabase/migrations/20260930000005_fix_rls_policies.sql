-- Fix RLS policies for link_opportunities and guest_post_pitches

ALTER TABLE IF EXISTS link_opportunities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "allow_service_role" ON link_opportunities;

CREATE POLICY "allow_service_role" ON link_opportunities
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Allow anonymous reads (for dashboard display)
CREATE POLICY "allow_anonymous_read" ON link_opportunities
  FOR SELECT
  USING (true);

ALTER TABLE IF EXISTS guest_post_pitches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "allow_service_role_pitches" ON guest_post_pitches;

CREATE POLICY "allow_service_role_pitches" ON guest_post_pitches
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Allow anonymous reads
CREATE POLICY "allow_anonymous_read_pitches" ON guest_post_pitches
  FOR SELECT
  USING (true);
