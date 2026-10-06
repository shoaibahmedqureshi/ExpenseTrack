-- Align family_invitations with what the app writes (table was created with
-- columns email/token/expires_at and no defaults, invited_by or status).
ALTER TABLE public.family_invitations
  ADD COLUMN IF NOT EXISTS invited_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ;

ALTER TABLE public.family_invitations
  ALTER COLUMN token SET DEFAULT replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
  ALTER COLUMN expires_at SET DEFAULT (now() + interval '7 days');

CREATE INDEX IF NOT EXISTS idx_family_invitations_status ON public.family_invitations(status);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'family_invitations' AND policyname = 'Admins can view sent invitations') THEN
    CREATE POLICY "Admins can view sent invitations" ON public.family_invitations FOR SELECT USING (
      family_id IN (SELECT id FROM public.family_groups WHERE user_id = auth.uid())
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'family_invitations' AND policyname = 'Invitees can respond to invitations') THEN
    CREATE POLICY "Invitees can respond to invitations" ON public.family_invitations FOR UPDATE USING (
      email = auth.jwt() ->> 'email'
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'family_invitations' AND policyname = 'Admins can update sent invitations') THEN
    CREATE POLICY "Admins can update sent invitations" ON public.family_invitations FOR UPDATE USING (
      family_id IN (SELECT id FROM public.family_groups WHERE user_id = auth.uid())
    );
  END IF;
END $$;

GRANT ALL ON public.family_invitations TO authenticated, service_role;
GRANT USAGE, SELECT ON SEQUENCE public.family_invitations_id_seq TO authenticated, service_role;
