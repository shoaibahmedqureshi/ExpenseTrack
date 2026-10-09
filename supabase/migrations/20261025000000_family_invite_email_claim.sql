-- send_family_invitation used to email whatever address a caller supplied, so anyone holding the public key could use it to
-- send mail from our domain. It now sends only for a real, pending invitation the caller created, once, with limits and an
-- opt-out, and takes the address and names from the database instead of from the request.

CREATE TABLE IF NOT EXISTS public.family_invite_emails (
  invitation_id BIGINT PRIMARY KEY REFERENCES public.family_invitations(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  sent_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_family_invite_emails_email ON public.family_invite_emails(email, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_family_invite_emails_sender ON public.family_invite_emails(sent_by, sent_at DESC);
ALTER TABLE public.family_invite_emails ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.family_invite_emails FROM anon, authenticated;

ALTER TABLE public.email_suppressions DROP CONSTRAINT IF EXISTS email_suppressions_scope_check;
ALTER TABLE public.email_suppressions ADD CONSTRAINT email_suppressions_scope_check CHECK (scope IN ('group_invite', 'family_invite'));

-- reasons: not_inviter, closed, opted_out, resent_recently, recipient_limited, sender_limited
CREATE OR REPLACE FUNCTION public.claim_family_invite_email(p_family_id BIGINT, p_token TEXT, p_user UUID) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE i family_invitations%ROWTYPE; v_family TEXT; v_last TIMESTAMPTZ;
BEGIN
  SELECT * INTO i FROM family_invitations WHERE family_id = p_family_id AND token = p_token FOR UPDATE;
  IF NOT FOUND OR i.invited_by IS DISTINCT FROM p_user THEN RETURN jsonb_build_object('ok', false, 'reason', 'not_inviter'); END IF;
  IF i.status <> 'pending' OR i.expires_at <= now() THEN RETURN jsonb_build_object('ok', false, 'reason', 'closed'); END IF;
  IF EXISTS (SELECT 1 FROM email_suppressions WHERE email = lower(i.email) AND scope = 'family_invite') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'opted_out');
  END IF;

  -- The app re-sends an open invitation instead of creating another; allow that, but not more than once an hour.
  SELECT sent_at INTO v_last FROM family_invite_emails WHERE invitation_id = i.id;
  IF FOUND AND v_last > now() - interval '1 hour' THEN RETURN jsonb_build_object('ok', false, 'reason', 'resent_recently'); END IF;

  IF EXISTS (SELECT 1 FROM family_invite_emails WHERE email = lower(i.email) AND invitation_id <> i.id AND sent_at > now() - interval '7 days') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'recipient_limited');
  END IF;
  IF (SELECT count(*) FROM family_invite_emails WHERE sent_by = p_user AND sent_at > now() - interval '1 day') >= 15 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'sender_limited');
  END IF;

  INSERT INTO family_invite_emails(invitation_id, email, sent_by) VALUES (i.id, lower(i.email), p_user)
    ON CONFLICT (invitation_id) DO UPDATE SET sent_at = now(), sent_by = p_user;
  SELECT name INTO v_family FROM family_groups WHERE id = i.family_id;
  RETURN jsonb_build_object('ok', true, 'email', lower(i.email), 'family_name', v_family,
                            'inviter_name', public.inbox_display_name(p_user), 'expires_at', i.expires_at, 'invitation_id', i.id,
                            'previous_sent_at', v_last);
END $$;

CREATE OR REPLACE FUNCTION public.release_family_invite_email(p_invitation_id BIGINT, p_previous TIMESTAMPTZ) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- Hand the claim back after a failed send: forget it if it was new, restore the old time if it was a re-send.
  IF p_previous IS NULL THEN DELETE FROM family_invite_emails WHERE invitation_id = p_invitation_id;
  ELSE UPDATE family_invite_emails SET sent_at = p_previous WHERE invitation_id = p_invitation_id; END IF;
END $$;
REVOKE ALL ON FUNCTION public.claim_family_invite_email(BIGINT, TEXT, UUID) FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public.release_family_invite_email(BIGINT, TIMESTAMPTZ) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_family_invite_email(BIGINT, TEXT, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.release_family_invite_email(BIGINT, TIMESTAMPTZ) TO service_role;
