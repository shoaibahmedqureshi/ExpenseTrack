-- Household view: members opt in to share monthly spending TOTALS per category
-- (never line items). The admin sets one recurring monthly household budget.

CREATE TABLE IF NOT EXISTS public.family_sharing (
  family_id BIGINT NOT NULL REFERENCES public.family_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  enabled BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (family_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.family_spending_summaries (
  family_id BIGINT NOT NULL REFERENCES public.family_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  month DATE NOT NULL CHECK (month = date_trunc('month', month)::date),
  category TEXT NOT NULL CHECK (length(btrim(category)) BETWEEN 1 AND 40),
  spent NUMERIC(14,2) NOT NULL CHECK (spent >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (family_id, user_id, month, category)
);
CREATE INDEX IF NOT EXISTS idx_family_summaries_family_month ON public.family_spending_summaries(family_id, month);

CREATE TABLE IF NOT EXISTS public.family_budgets (
  id BIGSERIAL PRIMARY KEY,
  family_id BIGINT NOT NULL REFERENCES public.family_groups(id) ON DELETE CASCADE,
  category TEXT CHECK (category IS NULL OR length(btrim(category)) BETWEEN 1 AND 40), -- NULL = overall
  amount NUMERIC(14,2) NOT NULL CHECK (amount > 0 AND amount < 1000000000),
  updated_by UUID REFERENCES auth.users(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_family_budgets ON public.family_budgets(family_id, COALESCE(category, ''));

ALTER TABLE public.family_sharing ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_spending_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_budgets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members read sharing state" ON public.family_sharing;
CREATE POLICY "Members read sharing state" ON public.family_sharing FOR SELECT
  USING (family_id IN (SELECT public.my_family_ids()));

DROP POLICY IF EXISTS "Members read summaries" ON public.family_spending_summaries;
CREATE POLICY "Members read summaries" ON public.family_spending_summaries FOR SELECT
  USING (family_id IN (SELECT public.my_family_ids()));

DROP POLICY IF EXISTS "Members read budgets" ON public.family_budgets;
CREATE POLICY "Members read budgets" ON public.family_budgets FOR SELECT
  USING (family_id IN (SELECT public.my_family_ids()));
DROP POLICY IF EXISTS "Owner writes budgets" ON public.family_budgets;
CREATE POLICY "Owner writes budgets" ON public.family_budgets FOR ALL
  USING (public.i_own_family(family_id)) WITH CHECK (public.i_own_family(family_id));

REVOKE ALL ON public.family_sharing, public.family_spending_summaries, public.family_budgets FROM authenticated;
GRANT SELECT ON public.family_sharing, public.family_spending_summaries TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.family_budgets TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.family_budgets_id_seq TO authenticated;

-- Turn sharing on/off for yourself. Turning it off deletes your shared totals.
CREATE OR REPLACE FUNCTION public.set_spending_sharing(p_family_id BIGINT, p_enabled BOOLEAN) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF NOT EXISTS (SELECT 1 FROM family_members WHERE family_id = p_family_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'You are not a member of this family';
  END IF;
  INSERT INTO family_sharing(family_id, user_id, enabled, updated_at)
    VALUES (p_family_id, auth.uid(), COALESCE(p_enabled, false), now())
  ON CONFLICT (family_id, user_id) DO UPDATE SET enabled = EXCLUDED.enabled, updated_at = now();
  IF NOT COALESCE(p_enabled, false) THEN
    DELETE FROM family_spending_summaries WHERE family_id = p_family_id AND user_id = auth.uid();
  END IF;
END $$;

-- Replace your shared totals from p_from onward with p_rows:
-- [{"month":"2026-10-01","category":"Food","spent":123.45}, ...]
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

  DELETE FROM family_spending_summaries WHERE family_id = p_family_id AND user_id = auth.uid() AND month >= p_from;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    IF (r->>'month')::date < p_from THEN RAISE EXCEPTION 'Row before p_from'; END IF;
    INSERT INTO family_spending_summaries(family_id, user_id, month, category, spent)
      VALUES (p_family_id, auth.uid(), (r->>'month')::date, btrim(r->>'category'), round((r->>'spent')::numeric, 2))
    ON CONFLICT (family_id, user_id, month, category) DO UPDATE SET spent = EXCLUDED.spent, updated_at = now();
  END LOOP;
  UPDATE family_sharing SET updated_at = now() WHERE family_id = p_family_id AND user_id = auth.uid();
END $$;

REVOKE ALL ON FUNCTION public.set_spending_sharing(BIGINT, BOOLEAN) FROM public;
REVOKE ALL ON FUNCTION public.publish_spending_summary(BIGINT, DATE, JSONB) FROM public;
GRANT EXECUTE ON FUNCTION public.set_spending_sharing(BIGINT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.publish_spending_summary(BIGINT, DATE, JSONB) TO authenticated;

-- Leaving or being removed from a family takes your shared totals with you.
CREATE OR REPLACE FUNCTION public.trg_family_member_left() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  DELETE FROM family_spending_summaries WHERE family_id = OLD.family_id AND user_id = OLD.user_id;
  DELETE FROM family_sharing WHERE family_id = OLD.family_id AND user_id = OLD.user_id;
  RETURN OLD;
END $$;
DROP TRIGGER IF EXISTS trg_family_member_left ON public.family_members;
CREATE TRIGGER trg_family_member_left AFTER DELETE ON public.family_members
  FOR EACH ROW EXECUTE FUNCTION public.trg_family_member_left();
