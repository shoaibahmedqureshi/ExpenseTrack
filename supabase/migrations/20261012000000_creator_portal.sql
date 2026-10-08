-- Creator portal: creators sign in (email link) and apply under their own account.

ALTER TABLE public.creator_applications
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS assigned_code TEXT CHECK (assigned_code IS NULL OR assigned_code ~ '^[A-Za-z0-9_-]{3,40}$');
CREATE UNIQUE INDEX IF NOT EXISTS uq_creator_applications_user ON public.creator_applications (user_id) WHERE user_id IS NOT NULL;

-- Admins may also set the creator's discount code when deciding.
GRANT UPDATE (assigned_code) ON public.creator_applications TO authenticated;

-- Creators never read the table directly (it holds admin notes and token hashes).
-- They go through these two functions, which only ever touch the caller's own row.

CREATE OR REPLACE FUNCTION public.my_creator_application() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT to_jsonb(r) FROM (
    SELECT name, email, platform, handle, profile_url, audience_band, niche, about, country,
           status, created_at, decided_at,
           CASE WHEN status IN ('approved','onboarded') THEN assigned_code END AS assigned_code
      FROM public.creator_applications WHERE user_id = auth.uid()
  ) r;
$$;
REVOKE ALL ON FUNCTION public.my_creator_application() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.my_creator_application() TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_creator_application(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid UUID := auth.uid();
  v_email TEXT;
  v_confirmed TIMESTAMPTZ;
  v_name TEXT := btrim(coalesce(p->>'name',''));
  v_platform TEXT := coalesce(p->>'platform','');
  v_handle TEXT := btrim(coalesce(p->>'handle',''));
  v_url TEXT := nullif(btrim(coalesce(p->>'profile_url','')),'');
  v_band TEXT := coalesce(p->>'audience_band','');
  v_niche TEXT := btrim(coalesce(p->>'niche',''));
  v_about TEXT := nullif(btrim(coalesce(p->>'about','')),'');
  v_country TEXT := nullif(btrim(coalesce(p->>'country','')),'');
  ex public.creator_applications%ROWTYPE;
  v_id BIGINT;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Please sign in first'; END IF;
  SELECT email, email_confirmed_at INTO v_email, v_confirmed FROM auth.users WHERE id = uid;
  IF v_email IS NULL OR v_confirmed IS NULL THEN RAISE EXCEPTION 'Your email is not confirmed yet'; END IF;
  IF coalesce((p->>'consent')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'Please agree so we can email you about the program'; END IF;
  IF length(v_name) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Please enter your name'; END IF;
  IF v_platform NOT IN ('tiktok','youtube','instagram','x','other') THEN RAISE EXCEPTION 'Choose a platform'; END IF;
  IF length(v_handle) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Please enter your handle or channel name'; END IF;
  IF v_url IS NOT NULL AND (length(v_url) > 300 OR v_url !~* '^https?://\S+$') THEN RAISE EXCEPTION 'Enter a full link starting with https://'; END IF;
  IF v_band NOT IN ('under_1k','1k_10k','10k_50k','50k_250k','over_250k') THEN RAISE EXCEPTION 'Choose your audience size'; END IF;
  IF length(v_niche) NOT BETWEEN 2 AND 120 THEN RAISE EXCEPTION 'Tell us what you create content about'; END IF;
  IF v_about IS NOT NULL AND length(v_about) > 1000 THEN RAISE EXCEPTION 'About is too long'; END IF;
  IF v_country IS NOT NULL AND length(v_country) > 60 THEN RAISE EXCEPTION 'Country is too long'; END IF;

  SELECT * INTO ex FROM public.creator_applications WHERE user_id = uid;
  IF NOT FOUND THEN
    -- An earlier form-based application for the same email is adopted rather than duplicated.
    SELECT * INTO ex FROM public.creator_applications WHERE lower(email) = lower(v_email) AND user_id IS NULL;
  END IF;

  IF FOUND THEN
    IF ex.status NOT IN ('pending_confirmation','confirmed') THEN
      RAISE EXCEPTION 'Your application has already been reviewed';
    END IF;
    UPDATE public.creator_applications SET
      user_id = uid, name = v_name, platform = v_platform, handle = v_handle, profile_url = v_url,
      audience_band = v_band, niche = v_niche, about = v_about, country = v_country,
      status = 'confirmed', confirmed_at = coalesce(confirmed_at, now()),
      confirm_token_hash = NULL, consent_at = now()
    WHERE id = ex.id RETURNING id INTO v_id;
    IF ex.status = 'confirmed' THEN RETURN public.my_creator_application(); END IF;
  ELSE
    INSERT INTO public.creator_applications
      (name, email, platform, handle, profile_url, audience_band, niche, about, country,
       consent_at, source, status, confirmed_at, user_id)
    VALUES (v_name, v_email, v_platform, v_handle, v_url, v_band, v_niche, v_about, v_country,
       now(), 'portal', 'confirmed', now(), uid)
    RETURNING id INTO v_id;
  END IF;

  INSERT INTO public.inbox_notifications (user_id, type, title, body, data)
    SELECT a.user_id, 'creator_application', 'New creator application',
           v_name || ' applied and is waiting for review.', jsonb_build_object('application_id', v_id)
      FROM public.app_admins a;

  RETURN public.my_creator_application();
END $$;
REVOKE ALL ON FUNCTION public.submit_creator_application(jsonb) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.submit_creator_application(jsonb) TO authenticated;
