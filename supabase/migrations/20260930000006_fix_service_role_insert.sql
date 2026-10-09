-- Drop old policies that don't allow INSERT
DROP POLICY IF EXISTS "service_role_all" ON link_opportunities;
DROP POLICY IF EXISTS "service_role_all_pitches" ON guest_post_pitches;

-- Create permissive policies for service_role (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'link_opportunities' AND policyname = 'service_role_insert') THEN
    CREATE POLICY "service_role_insert" ON link_opportunities FOR INSERT WITH CHECK (auth.role() = 'service_role');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'link_opportunities' AND policyname = 'service_role_select') THEN
    CREATE POLICY "service_role_select" ON link_opportunities FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'link_opportunities' AND policyname = 'service_role_update') THEN
    CREATE POLICY "service_role_update" ON link_opportunities FOR UPDATE USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'guest_post_pitches' AND policyname = 'service_role_insert_pitches') THEN
    CREATE POLICY "service_role_insert_pitches" ON guest_post_pitches FOR INSERT WITH CHECK (auth.role() = 'service_role');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'guest_post_pitches' AND policyname = 'service_role_select_pitches') THEN
    CREATE POLICY "service_role_select_pitches" ON guest_post_pitches FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'guest_post_pitches' AND policyname = 'service_role_update_pitches') THEN
    CREATE POLICY "service_role_update_pitches" ON guest_post_pitches FOR UPDATE USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
  END IF;
END $$;
