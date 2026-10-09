-- Live updates for the household budget: when anyone in a family shares, stops sharing, or the budget changes, the
-- other members' apps are told straight away. The message carries no figures, only "something changed", and a member
-- can only listen to their own family's channel, so nothing leaks to outsiders.

-- Who may listen: members of family N may subscribe to the private channel "household:N".
DROP POLICY IF EXISTS "Family members listen to household changes" ON realtime.messages;
CREATE POLICY "Family members listen to household changes" ON realtime.messages
  FOR SELECT TO authenticated
  USING (
    realtime.messages.extension = 'broadcast'
    AND CASE WHEN realtime.topic() ~ '^household:[0-9]+$'
             THEN EXISTS (SELECT 1 FROM public.family_members m
                           WHERE m.user_id = auth.uid() AND m.family_id = substring(realtime.topic() FROM 11)::bigint)
             ELSE false END
  );

CREATE OR REPLACE FUNCTION public.notify_household(p_family_id BIGINT) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM realtime.send(jsonb_build_object('family_id', p_family_id), 'changed', 'household:' || p_family_id::text, true);
EXCEPTION WHEN OTHERS THEN
  NULL; -- telling people is a courtesy; it must never make the real change fail
END $$;
REVOKE ALL ON FUNCTION public.notify_household(BIGINT) FROM public, anon, authenticated;

-- One message per statement that changes anything for a family (not one per row).
CREATE OR REPLACE FUNCTION public.trg_household_changed_new() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE f BIGINT;
BEGIN
  FOR f IN SELECT DISTINCT family_id FROM changed LOOP PERFORM public.notify_household(f); END LOOP;
  RETURN NULL;
END $$;
CREATE OR REPLACE FUNCTION public.trg_household_changed_old() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE f BIGINT;
BEGIN
  FOR f IN SELECT DISTINCT family_id FROM changed LOOP PERFORM public.notify_household(f); END LOOP;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.trg_household_changed_new() FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public.trg_household_changed_old() FROM public, anon, authenticated;

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['family_spending_summaries', 'family_sharing', 'family_budgets'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_live_ins ON public.%I', t, t);
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_live_upd ON public.%I', t, t);
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_live_del ON public.%I', t, t);
    EXECUTE format('CREATE TRIGGER trg_%s_live_ins AFTER INSERT ON public.%I REFERENCING NEW TABLE AS changed FOR EACH STATEMENT EXECUTE FUNCTION public.trg_household_changed_new()', t, t);
    EXECUTE format('CREATE TRIGGER trg_%s_live_upd AFTER UPDATE ON public.%I REFERENCING NEW TABLE AS changed FOR EACH STATEMENT EXECUTE FUNCTION public.trg_household_changed_new()', t, t);
    EXECUTE format('CREATE TRIGGER trg_%s_live_del AFTER DELETE ON public.%I REFERENCING OLD TABLE AS changed FOR EACH STATEMENT EXECUTE FUNCTION public.trg_household_changed_old()', t, t);
  END LOOP;
END $$;

-- Every change goes through the functions (which the triggers above cover), so no one writes budgets directly.
REVOKE INSERT, UPDATE, DELETE ON public.family_budgets FROM authenticated;

-- Publishing used to insert one row per statement; do it in one statement so a publish sends two messages, not dozens.
CREATE OR REPLACE FUNCTION public.publish_spending_summary(p_family_id BIGINT, p_from DATE, p_rows JSONB) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r JSONB;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF NOT EXISTS (SELECT 1 FROM family_sharing WHERE family_id = p_family_id AND user_id = auth.uid() AND enabled)
     OR NOT EXISTS (SELECT 1 FROM family_members WHERE family_id = p_family_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Spending sharing is not turned on for you';
  END IF;
  IF p_from IS NULL OR p_from <> date_trunc('month', p_from)::date THEN RAISE EXCEPTION 'p_from must be the first day of a month'; END IF;
  IF jsonb_typeof(p_rows) <> 'array' OR jsonb_array_length(p_rows) > 200 THEN RAISE EXCEPTION 'Too many rows'; END IF;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    IF (r->>'month')::date < p_from THEN RAISE EXCEPTION 'Row before p_from'; END IF;
  END LOOP;

  DELETE FROM family_spending_summaries WHERE family_id = p_family_id AND user_id = auth.uid() AND month >= p_from;

  INSERT INTO family_spending_summaries(family_id, user_id, month, category, spent)
    SELECT p_family_id, auth.uid(), (x->>'month')::date, btrim(x->>'category'), sum(round((x->>'spent')::numeric, 2))
      FROM jsonb_array_elements(p_rows) x
     GROUP BY (x->>'month')::date, btrim(x->>'category')
  ON CONFLICT (family_id, user_id, month, category) DO UPDATE SET spent = EXCLUDED.spent, updated_at = now();
  UPDATE family_sharing SET updated_at = now() WHERE family_id = p_family_id AND user_id = auth.uid();
END $$;
