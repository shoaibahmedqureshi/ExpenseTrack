-- Creator earnings: a creator sees only the attributed purchases for their own discount code.
-- Source of truth is subscription_referrals, which only the store webhooks (service role) write.

-- One creator per code, so earnings can never be shown to the wrong person.
CREATE UNIQUE INDEX IF NOT EXISTS uq_creator_applications_code
  ON public.creator_applications (lower(assigned_code)) WHERE assigned_code IS NOT NULL;

CREATE OR REPLACE FUNCTION public.my_creator_earnings() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_code TEXT;
  v_status TEXT;
  v_result jsonb;
BEGIN
  SELECT assigned_code, status INTO v_code, v_status FROM public.creator_applications WHERE user_id = auth.uid();
  IF v_code IS NULL OR v_status NOT IN ('approved','onboarded') THEN RETURN NULL; END IF;

  WITH mine AS (
    SELECT r.created_at, r.platform, r.payout_amount, r.currency, r.payout_status
      FROM public.subscription_referrals r
      JOIN public.influencer_codes c ON c.id = r.influencer_code_id
     WHERE lower(c.code) = lower(v_code) AND r.payout_status <> 'void' AND r.payout_amount IS NOT NULL
  )
  SELECT jsonb_build_object(
    'code', v_code,
    'share_percent', (SELECT max(revenue_share_percent) FROM public.influencer_codes WHERE lower(code) = lower(v_code)),
    'conversions', (SELECT count(*) FROM mine),
    'totals', coalesce((SELECT jsonb_agg(jsonb_build_object(
        'currency', currency,
        'pending', pending,
        'paid', paid)) FROM (
          SELECT coalesce(currency,'') AS currency,
                 coalesce(sum(payout_amount) FILTER (WHERE payout_status = 'pending'), 0) AS pending,
                 coalesce(sum(payout_amount) FILTER (WHERE payout_status = 'paid'), 0) AS paid
            FROM mine GROUP BY coalesce(currency,'')) t), '[]'::jsonb),
    'recent', coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (
        SELECT created_at, platform, payout_amount, currency, payout_status FROM mine ORDER BY created_at DESC LIMIT 50) x), '[]'::jsonb)
  ) INTO v_result;
  RETURN v_result;
END $$;
REVOKE ALL ON FUNCTION public.my_creator_earnings() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.my_creator_earnings() TO authenticated;
