-- These four tables belong to the back-office agents and are only ever used by edge functions and scheduled jobs through
-- the service role. They had Row Level Security off and full privileges for the public anon role, so anyone holding the app's
-- public key could read, change or wipe them. Turn RLS on (no policies = no client access) and take the privileges away.
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['agent_logs', 'email_drafts', 'profile_links', 'seo_activity_log'] LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
      EXECUTE format('REVOKE ALL ON public.%I FROM anon, authenticated', t);
    END IF;
  END LOOP;
END $$;
