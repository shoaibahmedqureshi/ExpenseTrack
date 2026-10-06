-- Expense splits: a ledger of shared expenses plus recorded settle-up payments.
CREATE TABLE IF NOT EXISTS public.expense_splits (
  id BIGSERIAL PRIMARY KEY,
  family_id BIGINT NOT NULL REFERENCES public.family_groups(id) ON DELETE CASCADE,
  paid_by UUID NOT NULL REFERENCES auth.users(id),
  created_by UUID NOT NULL REFERENCES auth.users(id),
  description TEXT NOT NULL CHECK (length(btrim(description)) BETWEEN 1 AND 120),
  total_amount NUMERIC(14,2) NOT NULL CHECK (total_amount > 0),
  split_type TEXT NOT NULL CHECK (split_type IN ('equal','amount','percent')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.expense_split_shares (
  id BIGSERIAL PRIMARY KEY,
  split_id BIGINT NOT NULL REFERENCES public.expense_splits(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  amount NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
  percent NUMERIC(6,3) CHECK (percent IS NULL OR (percent >= 0 AND percent <= 100)),
  UNIQUE (split_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.expense_settlements (
  id BIGSERIAL PRIMARY KEY,
  family_id BIGINT NOT NULL REFERENCES public.family_groups(id) ON DELETE CASCADE,
  from_user UUID NOT NULL REFERENCES auth.users(id),
  to_user UUID NOT NULL REFERENCES auth.users(id),
  amount NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (from_user <> to_user)
);

CREATE INDEX IF NOT EXISTS idx_expense_splits_family ON public.expense_splits(family_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_expense_split_shares_split ON public.expense_split_shares(split_id);
CREATE INDEX IF NOT EXISTS idx_expense_settlements_family ON public.expense_settlements(family_id, created_at DESC);

ALTER TABLE public.expense_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_split_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_settlements ENABLE ROW LEVEL SECURITY;

-- Members read their family's ledger. Writes go through the functions below.
DROP POLICY IF EXISTS "Members read splits" ON public.expense_splits;
CREATE POLICY "Members read splits" ON public.expense_splits FOR SELECT
  USING (family_id IN (SELECT public.my_family_ids()));

DROP POLICY IF EXISTS "Members read shares" ON public.expense_split_shares;
CREATE POLICY "Members read shares" ON public.expense_split_shares FOR SELECT
  USING (split_id IN (SELECT id FROM public.expense_splits WHERE family_id IN (SELECT public.my_family_ids())));

DROP POLICY IF EXISTS "Members read settlements" ON public.expense_settlements;
CREATE POLICY "Members read settlements" ON public.expense_settlements FOR SELECT
  USING (family_id IN (SELECT public.my_family_ids()));

DROP POLICY IF EXISTS "Creator or owner deletes split" ON public.expense_splits;
CREATE POLICY "Creator or owner deletes split" ON public.expense_splits FOR DELETE
  USING (created_by = auth.uid() OR public.i_own_family(family_id));

DROP POLICY IF EXISTS "Creator or owner deletes settlement" ON public.expense_settlements;
CREATE POLICY "Creator or owner deletes settlement" ON public.expense_settlements FOR DELETE
  USING (created_by = auth.uid() OR public.i_own_family(family_id));

GRANT SELECT, DELETE ON public.expense_splits, public.expense_split_shares, public.expense_settlements TO authenticated;

-- Create a split and its shares atomically, validating membership and totals.
-- p_shares: [{"user_id": "...", "amount": 12.34, "percent": 50}, ...]
CREATE OR REPLACE FUNCTION public.create_expense_split(
  p_family_id BIGINT, p_paid_by UUID, p_description TEXT,
  p_total NUMERIC, p_split_type TEXT, p_shares JSONB
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id BIGINT; v_sum NUMERIC; v_n INT; v_distinct INT; s JSONB;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF NOT EXISTS (SELECT 1 FROM family_members WHERE family_id = p_family_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'You are not a member of this family';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM family_members WHERE family_id = p_family_id AND user_id = p_paid_by) THEN
    RAISE EXCEPTION 'The person who paid is not in this family';
  END IF;
  IF p_split_type NOT IN ('equal','amount','percent') THEN RAISE EXCEPTION 'Unknown split type'; END IF;
  IF p_total IS NULL OR p_total <= 0 THEN RAISE EXCEPTION 'Total must be greater than zero'; END IF;
  IF jsonb_typeof(p_shares) <> 'array' OR jsonb_array_length(p_shares) = 0 THEN
    RAISE EXCEPTION 'Choose at least one person to split with';
  END IF;

  SELECT count(*), count(DISTINCT x->>'user_id'), COALESCE(sum(round((x->>'amount')::numeric, 2)), 0)
    INTO v_n, v_distinct, v_sum FROM jsonb_array_elements(p_shares) x;
  IF v_n <> v_distinct THEN RAISE EXCEPTION 'A person appears twice in the split'; END IF;
  IF v_sum <> round(p_total, 2) THEN RAISE EXCEPTION 'Shares (%) do not add up to the total (%)', v_sum, round(p_total, 2); END IF;

  FOR s IN SELECT * FROM jsonb_array_elements(p_shares) LOOP
    IF NOT EXISTS (SELECT 1 FROM family_members WHERE family_id = p_family_id AND user_id = (s->>'user_id')::uuid) THEN
      RAISE EXCEPTION 'Everyone in the split must be a family member';
    END IF;
    IF (s->>'amount')::numeric < 0 THEN RAISE EXCEPTION 'Amounts cannot be negative'; END IF;
  END LOOP;

  INSERT INTO expense_splits(family_id, paid_by, created_by, description, total_amount, split_type)
    VALUES (p_family_id, p_paid_by, auth.uid(), btrim(p_description), round(p_total, 2), p_split_type)
    RETURNING id INTO v_id;

  INSERT INTO expense_split_shares(split_id, user_id, amount, percent)
    SELECT v_id, (x->>'user_id')::uuid, round((x->>'amount')::numeric, 2), NULLIF(x->>'percent','')::numeric
    FROM jsonb_array_elements(p_shares) x;

  RETURN v_id;
END $$;

-- Record that money changed hands between two members (either party may log it).
CREATE OR REPLACE FUNCTION public.record_settlement(
  p_family_id BIGINT, p_from UUID, p_to UUID, p_amount NUMERIC
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id BIGINT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF auth.uid() NOT IN (p_from, p_to) THEN RAISE EXCEPTION 'You can only record payments you made or received'; END IF;
  IF p_from = p_to THEN RAISE EXCEPTION 'Choose two different people'; END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be greater than zero'; END IF;
  IF (SELECT count(*) FROM family_members WHERE family_id = p_family_id AND user_id IN (p_from, p_to)) <> 2 THEN
    RAISE EXCEPTION 'Both people must be members of this family';
  END IF;
  INSERT INTO expense_settlements(family_id, from_user, to_user, amount, created_by)
    VALUES (p_family_id, p_from, p_to, round(p_amount, 2), auth.uid()) RETURNING id INTO v_id;
  RETURN v_id;
END $$;

REVOKE ALL ON FUNCTION public.create_expense_split(BIGINT, UUID, TEXT, NUMERIC, TEXT, JSONB) FROM public;
REVOKE ALL ON FUNCTION public.record_settlement(BIGINT, UUID, UUID, NUMERIC) FROM public;
GRANT EXECUTE ON FUNCTION public.create_expense_split(BIGINT, UUID, TEXT, NUMERIC, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_settlement(BIGINT, UUID, UUID, NUMERIC) TO authenticated;
