-- Automatic void / restore of attributed purchases when a store reports a refund.
-- Called only by the store webhooks (service role). Never exposed to app users or the portal.

CREATE OR REPLACE FUNCTION public.system_void_referral(p_platform TEXT, p_transaction_id TEXT, p_reason TEXT, p_order_id TEXT DEFAULT NULL)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r public.subscription_referrals%ROWTYPE;
  v_first_order TEXT;
  v_name TEXT;
BEGIN
  SELECT * INTO r FROM public.subscription_referrals WHERE platform = p_platform AND transaction_id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN RETURN 'not_tracked'; END IF;
  IF r.payout_status = 'void' THEN RETURN 'already_void'; END IF;

  -- Google keeps one row per purchase token across renewals, and the creator is paid on the first
  -- (discounted) order only. A refund of a later order must not void that payout.
  IF p_order_id IS NOT NULL THEN
    v_first_order := r.raw_notification ->> 'latestOrderId';
    IF v_first_order IS NULL THEN
      SELECT coalesce(max(influencer_name), 'a creator') INTO v_name FROM public.influencer_codes WHERE id = r.influencer_code_id;
      INSERT INTO public.inbox_notifications (user_id, type, title, body, data)
        SELECT a.user_id, 'refund_review', 'Refund needs review',
               'Google Play reported a refund for ' || v_name || ' but the original order is unknown. Check the purchase by hand.',
               jsonb_build_object('referral_id', r.id)
          FROM public.app_admins a;
      RETURN 'unverifiable';
    END IF;
    IF v_first_order <> p_order_id THEN RETURN 'other_order'; END IF;
  END IF;

  UPDATE public.subscription_referrals
     SET payout_status = 'void', voided_from = r.payout_status, voided_at = now(), voided_by = NULL,
         void_reason = left(btrim(p_reason), 300)
   WHERE id = r.id;

  -- Money already sent for a purchase that was then refunded needs a person's attention.
  IF r.payout_status = 'paid' THEN
    SELECT coalesce(max(influencer_name), 'a creator') INTO v_name FROM public.influencer_codes WHERE id = r.influencer_code_id;
    INSERT INTO public.inbox_notifications (user_id, type, title, body, data)
      SELECT a.user_id, 'payout_clawback', 'Refunded purchase was already paid',
             'A purchase for ' || v_name || ' was refunded after you paid it'
               || CASE WHEN r.payout_amount IS NOT NULL THEN ' (' || r.payout_amount || ' ' || coalesce(r.currency,'') || ')' ELSE '' END
               || '. Recover or offset the payment.',
             jsonb_build_object('referral_id', r.id)
        FROM public.app_admins a;
    RETURN 'voided_was_paid';
  END IF;
  RETURN 'voided';
END $$;
REVOKE ALL ON FUNCTION public.system_void_referral(TEXT, TEXT, TEXT, TEXT) FROM public, anon, authenticated;

-- Apple can reverse a refund. Only a purchase the system itself voided is restored, never one an admin voided.
CREATE OR REPLACE FUNCTION public.system_restore_referral(p_platform TEXT, p_transaction_id TEXT) RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r public.subscription_referrals%ROWTYPE;
BEGIN
  SELECT * INTO r FROM public.subscription_referrals WHERE platform = p_platform AND transaction_id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN RETURN 'not_tracked'; END IF;
  IF r.payout_status <> 'void' OR r.voided_by IS NOT NULL OR r.voided_from IS NULL THEN RETURN 'not_system_void'; END IF;
  UPDATE public.subscription_referrals
     SET payout_status = r.voided_from, voided_from = NULL, voided_at = NULL, void_reason = NULL
   WHERE id = r.id;
  RETURN 'restored';
END $$;
REVOKE ALL ON FUNCTION public.system_restore_referral(TEXT, TEXT) FROM public, anon, authenticated;
