-- Void (and restore) individual attributed purchases, e.g. after a store refund. Admin-only, MFA enforced.

ALTER TABLE public.subscription_referrals
  ADD COLUMN IF NOT EXISTS voided_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS voided_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS void_reason TEXT CHECK (void_reason IS NULL OR length(void_reason) <= 300),
  ADD COLUMN IF NOT EXISTS voided_from TEXT CHECK (voided_from IS NULL OR voided_from IN ('pending','paid'));

-- Every purchase attributed to one creator's code, newest first (includes void and rows with no amount yet).
CREATE OR REPLACE FUNCTION public.admin_creator_referrals(p_application BIGINT) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_code TEXT;
BEGIN
  PERFORM public.assert_payout_admin();
  SELECT assigned_code INTO v_code FROM public.creator_applications WHERE id = p_application;
  IF v_code IS NULL THEN RETURN '[]'::jsonb; END IF;
  RETURN coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (
    SELECT r.id, r.created_at, r.platform, r.event_type, r.payout_amount, r.currency, r.payout_status,
           r.payout_note, r.void_reason, r.voided_from
      FROM public.subscription_referrals r
      JOIN public.influencer_codes c ON c.id = r.influencer_code_id
     WHERE lower(c.code) = lower(v_code)
     ORDER BY r.created_at DESC LIMIT 200) x), '[]'::jsonb);
END $$;
REVOKE ALL ON FUNCTION public.admin_creator_referrals(BIGINT) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_creator_referrals(BIGINT) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_void_referral(p_id BIGINT, p_reason TEXT) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r public.subscription_referrals%ROWTYPE;
BEGIN
  PERFORM public.assert_payout_admin();
  IF length(btrim(coalesce(p_reason,''))) < 3 THEN RAISE EXCEPTION 'Please give a reason (for example "refunded")'; END IF;
  SELECT * INTO r FROM public.subscription_referrals WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Purchase not found'; END IF;
  IF r.payout_status = 'void' THEN RAISE EXCEPTION 'Already void'; END IF;
  UPDATE public.subscription_referrals
     SET payout_status = 'void', voided_from = r.payout_status, voided_at = now(), voided_by = auth.uid(), void_reason = btrim(p_reason)
   WHERE id = p_id;
  -- A paid purchase that is voided means money already sent should be recovered or offset.
  RETURN jsonb_build_object('id', p_id, 'was_paid', r.payout_status = 'paid', 'amount', r.payout_amount, 'currency', r.currency);
END $$;
REVOKE ALL ON FUNCTION public.admin_void_referral(BIGINT, TEXT) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_void_referral(BIGINT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_restore_referral(p_id BIGINT) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r public.subscription_referrals%ROWTYPE;
BEGIN
  PERFORM public.assert_payout_admin();
  SELECT * INTO r FROM public.subscription_referrals WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR r.payout_status <> 'void' OR r.voided_from IS NULL THEN RAISE EXCEPTION 'Only a purchase voided from this screen can be restored'; END IF;
  UPDATE public.subscription_referrals
     SET payout_status = r.voided_from, voided_from = NULL, voided_at = NULL, voided_by = NULL, void_reason = NULL
   WHERE id = p_id;
  RETURN jsonb_build_object('id', p_id, 'status', r.voided_from);
END $$;
REVOKE ALL ON FUNCTION public.admin_restore_referral(BIGINT) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_restore_referral(BIGINT) TO authenticated;
