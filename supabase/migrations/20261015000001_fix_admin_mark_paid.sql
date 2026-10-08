-- Fix: FOR UPDATE cannot be combined with aggregates directly; lock inside a CTE.
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

  -- Lock the rows first so a concurrent webhook or second click cannot change them mid-payment.
  WITH locked AS (
    SELECT r.id, r.payout_amount
      FROM public.subscription_referrals r
      JOIN public.influencer_codes c ON c.id = r.influencer_code_id
     WHERE lower(c.code) = lower(v_code) AND r.payout_status = 'pending' AND r.payout_amount IS NOT NULL
       AND coalesce(r.currency,'') = coalesce(p_currency,'')
       FOR UPDATE OF r
  )
  SELECT array_agg(id), coalesce(sum(payout_amount), 0) INTO v_ids, v_total FROM locked;

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
