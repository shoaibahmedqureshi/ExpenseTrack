-- influencer_revenue had two extra permissive policies (enable_read USING true, enable_insert WITH CHECK true)
-- that let anyone, signed in or not, read every row and insert arbitrary rows. Remove them; the original
-- per-user policies ("Users can view own revenue" / "Users can insert own revenue") remain.
DROP POLICY IF EXISTS enable_read ON public.influencer_revenue;
DROP POLICY IF EXISTS enable_insert ON public.influencer_revenue;
REVOKE ALL ON public.influencer_revenue FROM anon;
