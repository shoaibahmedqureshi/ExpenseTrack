-- Admin payouts: see what each creator is owed and mark it paid. Admin-only and requires MFA (aal2),
-- enforced here in the database because this moves money records.

ALTER TABLE public.subscription_referrals
  ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS paid_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS payout_note TEXT CHECK (payout_note IS NULL OR length(payout_note) <= 300);

CREATE OR REPLACE FUNCTION public.assert_payout_admin() RETURNS VOID
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_app_admin() THEN RAISE EXCEPTION 'Admins only'; END IF;
  IF coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' THEN RAISE EXCEPTION 'Verify with your authenticator app first'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.assert_payout_admin() FROM public, anon, authenticated;

-- One row per creator with a code: counts and amounts per currency, split into pending and paid.
CREATE OR REPLACE FUNCTION public.admin_creator_payouts() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.assert_payout_admin();
  RETURN coalesce((
    SELECT jsonb_agg(jsonb_build_object(
      'application_id', a.id, 'name', a.name, 'email', a.email, 'code', a.assigned_code,
      'rows', coalesce((
        SELECT jsonb_agg(jsonb_build_object('currency', currency, 'pending', pending, 'pending_count', pending_count, 'paid', paid))
          FROM (
            SELECT coalesce(r.currency,'') AS currency,
                   coalesce(sum(r.payout_amount) FILTER (WHERE r.payout_status = 'pending'), 0) AS pending,
                   count(*) FILTER (WHERE r.payout_status = 'pending') AS pending_count,
                   coalesce(sum(r.payout_amount) FILTER (WHERE r.payout_status = 'paid'), 0) AS paid
              FROM public.subscription_referrals r
              JOIN public.influencer_codes c ON c.id = r.influencer_code_id
             WHERE lower(c.code) = lower(a.assigned_code) AND r.payout_status <> 'void' AND r.payout_amount IS NOT NULL
             GROUP BY coalesce(r.currency,'')) t), '[]'::jsonb)
    ) ORDER BY a.name)
    FROM public.creator_applications a WHERE a.assigned_code IS NOT NULL AND a.status IN ('approved','onboarded')
  ), '[]'::jsonb);
END $$;
REVOKE ALL ON FUNCTION public.admin_creator_payouts() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_creator_payouts() TO authenticated;

-- Marks every pending payout for one creator in one currency as paid. The caller passes the amount they
-- just sent; if more purchases arrived since the screen loaded the totals differ and nothing is changed.
CREATE OR REPLACE FUNCTION public.admin_mark_paid(p_application BIGINT, p_currency TEXT, p_expected NUMERIC, p_note TEXT DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_code TEXT;
  v_total NUMERIC;
  v_ids BIGINT[];
BEGIN
  PERFORM public.assert_payout_admin();
  SELECT assigned_code INTO v_code FROM public.creator_applications
   WHERE id = p_application AND status IN ('approved','onboarded');
  IF v_code IS NULL THEN RAISE EXCEPTION 'That creator has no code to pay'; END IF;

  SELECT array_agg(r.id), coalesce(sum(r.payout_amount), 0) INTO v_ids, v_total
    FROM public.subscription_referrals r
    JOIN public.influencer_codes c ON c.id = r.influencer_code_id
   WHERE lower(c.code) = lower(v_code) AND r.payout_status = 'pending' AND r.payout_amount IS NOT NULL
     AND coalesce(r.currency,'') = coalesce(p_currency,'')
   FOR UPDATE OF r;

  IF v_ids IS NULL THEN RAISE EXCEPTION 'Nothing pending in %', coalesce(nullif(p_currency,''), 'that currency'); END IF;
  IF v_total <> p_expected THEN
    RAISE EXCEPTION 'The pending total changed to % (you expected %). Reload and check again.', v_total, p_expected;
  END IF;

  UPDATE public.subscription_referrals
     SET payout_status = 'paid', paid_at = now(), paid_by = auth.uid(), payout_note = nullif(btrim(p_note), '')
   WHERE id = ANY(v_ids);
  RETURN jsonb_build_object('paid_count', array_length(v_ids, 1), 'amount', v_total, 'currency', p_currency);
END $$;
REVOKE ALL ON FUNCTION public.admin_mark_paid(BIGINT, TEXT, NUMERIC, TEXT) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_mark_paid(BIGINT, TEXT, NUMERIC, TEXT) TO authenticated;
