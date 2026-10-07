-- Creator program: public applications (double opt-in) + an admin outreach task queue.

-- ── Who is an app admin ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_admins (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.app_admins ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_admins FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.is_app_admin() RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.app_admins WHERE user_id = auth.uid());
$$;
REVOKE ALL ON FUNCTION public.is_app_admin() FROM public;
GRANT EXECUTE ON FUNCTION public.is_app_admin() TO authenticated;

INSERT INTO public.app_admins(user_id)
  SELECT id FROM auth.users WHERE email IN ('08bitsaqureshi@seecs.edu.pk', 'shoaib.elastica@gmail.com')
ON CONFLICT DO NOTHING;

-- ── Creator applications ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.creator_applications (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 100),
  email TEXT NOT NULL CHECK (length(email) BETWEEN 5 AND 200),
  platform TEXT NOT NULL CHECK (platform IN ('tiktok','youtube','instagram','x','other')),
  handle TEXT NOT NULL CHECK (length(btrim(handle)) BETWEEN 1 AND 100),
  profile_url TEXT CHECK (profile_url IS NULL OR (length(profile_url) <= 300 AND profile_url ~* '^https?://')),
  audience_band TEXT NOT NULL CHECK (audience_band IN ('under_1k','1k_10k','10k_50k','50k_250k','over_250k')),
  niche TEXT NOT NULL CHECK (length(btrim(niche)) BETWEEN 2 AND 120),
  about TEXT CHECK (about IS NULL OR length(about) <= 1000),
  country TEXT CHECK (country IS NULL OR length(country) <= 60),
  consent_at TIMESTAMPTZ NOT NULL,
  source TEXT CHECK (source IS NULL OR length(source) <= 80),
  status TEXT NOT NULL DEFAULT 'pending_confirmation'
    CHECK (status IN ('pending_confirmation','confirmed','approved','rejected','onboarded')),
  confirm_token_hash TEXT,
  confirm_sent_at TIMESTAMPTZ,
  confirmed_at TIMESTAMPTZ,
  admin_notes TEXT CHECK (admin_notes IS NULL OR length(admin_notes) <= 2000),
  decided_by UUID REFERENCES auth.users(id),
  decided_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_creator_applications_email ON public.creator_applications (lower(email));
CREATE INDEX IF NOT EXISTS idx_creator_applications_status ON public.creator_applications (status, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_creator_applications_token ON public.creator_applications (confirm_token_hash) WHERE confirm_token_hash IS NOT NULL;

-- Throttle table: written only by the edge function (service role).
CREATE TABLE IF NOT EXISTS public.creator_apply_attempts (
  id BIGSERIAL PRIMARY KEY,
  ip_hash TEXT NOT NULL,
  email_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_creator_attempts_ip ON public.creator_apply_attempts (ip_hash, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_creator_attempts_email ON public.creator_apply_attempts (email_hash, created_at DESC);

-- ── Outreach task queue ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.outreach_tasks (
  id BIGSERIAL PRIMARY KEY,
  product TEXT NOT NULL DEFAULT 'outlay',
  creator_name TEXT NOT NULL CHECK (length(btrim(creator_name)) BETWEEN 1 AND 120),
  platform TEXT NOT NULL CHECK (platform IN ('tiktok','youtube','instagram','x','email','other')),
  handle TEXT CHECK (handle IS NULL OR length(handle) <= 100),
  profile_url TEXT CHECK (profile_url IS NULL OR (length(profile_url) <= 300 AND profile_url ~* '^https?://')),
  channel TEXT NOT NULL CHECK (channel IN ('tiktok_invite','instagram_dm','youtube_email','email','other')),
  niche TEXT CHECK (niche IS NULL OR length(niche) <= 120),
  fit_reason TEXT CHECK (fit_reason IS NULL OR length(fit_reason) <= 1000),
  evidence TEXT CHECK (evidence IS NULL OR length(evidence) <= 2000),
  draft_message TEXT CHECK (draft_message IS NULL OR length(draft_message) <= 4000),
  status TEXT NOT NULL DEFAULT 'todo' CHECK (status IN ('todo','sent','replied','declined','done','snoozed')),
  due_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  followup_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  notes TEXT CHECK (notes IS NULL OR length(notes) <= 2000),
  source TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','agent','application')),
  application_id BIGINT REFERENCES public.creator_applications(id) ON DELETE SET NULL,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_outreach_tasks_status_due ON public.outreach_tasks (status, due_at);

CREATE OR REPLACE FUNCTION public.touch_updated_at() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;
DROP TRIGGER IF EXISTS trg_creator_applications_touch ON public.creator_applications;
CREATE TRIGGER trg_creator_applications_touch BEFORE UPDATE ON public.creator_applications FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
DROP TRIGGER IF EXISTS trg_outreach_tasks_touch ON public.outreach_tasks;
CREATE TRIGGER trg_outreach_tasks_touch BEFORE UPDATE ON public.outreach_tasks FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- ── Access: admins only; anonymous and normal users see nothing ───────
ALTER TABLE public.creator_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.creator_apply_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.outreach_tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins read applications" ON public.creator_applications;
CREATE POLICY "Admins read applications" ON public.creator_applications FOR SELECT USING (public.is_app_admin());
DROP POLICY IF EXISTS "Admins decide applications" ON public.creator_applications;
CREATE POLICY "Admins decide applications" ON public.creator_applications FOR UPDATE USING (public.is_app_admin()) WITH CHECK (public.is_app_admin());

DROP POLICY IF EXISTS "Admins manage tasks" ON public.outreach_tasks;
CREATE POLICY "Admins manage tasks" ON public.outreach_tasks FOR ALL USING (public.is_app_admin()) WITH CHECK (public.is_app_admin());

REVOKE ALL ON public.creator_applications, public.creator_apply_attempts, public.outreach_tasks FROM anon, authenticated;
GRANT SELECT ON public.creator_applications TO authenticated;
-- Admins may change only the decision fields of an application, never the applicant's own answers.
GRANT UPDATE (status, admin_notes, decided_by, decided_at) ON public.creator_applications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.outreach_tasks TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.outreach_tasks_id_seq TO authenticated;
