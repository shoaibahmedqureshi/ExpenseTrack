-- Household budget, step 2: the owner's budget functions and one call that returns the whole household view.
-- (Tables, opt-in and publishing were created in 20261010000000_household_sharing.sql.)

-- Owner sets the monthly household budget: p_category NULL means the overall budget.
CREATE OR REPLACE FUNCTION public.set_family_budget(p_family_id BIGINT, p_category TEXT, p_amount NUMERIC) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_cat TEXT := nullif(btrim(coalesce(p_category, '')), '');
BEGIN
  IF NOT public.i_own_family(p_family_id) THEN RAISE EXCEPTION 'Only the family admin can set the budget'; END IF;
  IF v_cat IS NOT NULL AND length(v_cat) > 40 THEN RAISE EXCEPTION 'Category name is too long'; END IF;
  IF p_amount IS NULL OR p_amount <= 0 OR p_amount >= 1000000000 THEN RAISE EXCEPTION 'Enter an amount greater than zero'; END IF;
  INSERT INTO family_budgets(family_id, category, amount, updated_by, updated_at)
    VALUES (p_family_id, v_cat, round(p_amount, 2), auth.uid(), now())
  ON CONFLICT (family_id, (COALESCE(category, ''))) DO UPDATE
    SET amount = EXCLUDED.amount, updated_by = auth.uid(), updated_at = now();
END $$;

CREATE OR REPLACE FUNCTION public.clear_family_budget(p_family_id BIGINT, p_category TEXT) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.i_own_family(p_family_id) THEN RAISE EXCEPTION 'Only the family admin can change the budget'; END IF;
  DELETE FROM family_budgets WHERE family_id = p_family_id AND COALESCE(category, '') = COALESCE(nullif(btrim(coalesce(p_category, '')), ''), '');
END $$;

-- The household view for one month. Members who have not opted in appear with sharing = false and no figures.
CREATE OR REPLACE FUNCTION public.household_overview(p_family_id BIGINT, p_month DATE) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_month DATE := date_trunc('month', coalesce(p_month, current_date))::date;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM family_members WHERE family_id = p_family_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'You are not a member of this family';
  END IF;
  RETURN jsonb_build_object(
    'month', v_month,
    'members', coalesce((SELECT jsonb_agg(jsonb_build_object(
        'user_id', m.user_id,
        'name', public.inbox_display_name(m.user_id),
        'email', m.email,
        'is_owner', (m.role = 'admin'),
        'sharing', coalesce(fs.enabled, false),
        'categories', CASE WHEN coalesce(fs.enabled, false) THEN coalesce((
            SELECT jsonb_agg(jsonb_build_object('category', s.category, 'spent', s.spent) ORDER BY s.spent DESC)
              FROM family_spending_summaries s
             WHERE s.family_id = m.family_id AND s.user_id = m.user_id AND s.month = v_month), '[]'::jsonb)
          ELSE '[]'::jsonb END
      ) ORDER BY m.joined_at)
      FROM family_members m LEFT JOIN family_sharing fs ON fs.family_id = m.family_id AND fs.user_id = m.user_id
     WHERE m.family_id = p_family_id), '[]'::jsonb),
    'budgets', coalesce((SELECT jsonb_agg(jsonb_build_object('category', b.category, 'amount', b.amount) ORDER BY b.category NULLS FIRST)
                           FROM family_budgets b WHERE b.family_id = p_family_id), '[]'::jsonb)
  );
END $$;

REVOKE ALL ON FUNCTION public.set_family_budget(BIGINT, TEXT, NUMERIC) FROM public, anon;
REVOKE ALL ON FUNCTION public.clear_family_budget(BIGINT, TEXT) FROM public, anon;
REVOKE ALL ON FUNCTION public.household_overview(BIGINT, DATE) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.set_family_budget(BIGINT, TEXT, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clear_family_budget(BIGINT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.household_overview(BIGINT, DATE) TO authenticated;
