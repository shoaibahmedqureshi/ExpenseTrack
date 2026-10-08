-- Emailing a split-group invitation to someone who has no Outlay account yet.
-- The edge function claims the right to send through claim_group_invite_email, which is where every
-- abuse limit lives, so a user cannot turn the invite box into a way to mail strangers.

CREATE TABLE IF NOT EXISTS public.group_invite_emails (
  invitation_id BIGINT PRIMARY KEY REFERENCES public.split_group_invitations(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  sent_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_group_invite_emails_email ON public.group_invite_emails(email, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_group_invite_emails_sender ON public.group_invite_emails(sent_by, sent_at DESC);
ALTER TABLE public.group_invite_emails ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.group_invite_emails FROM anon, authenticated;

-- Returns {ok:true, email, group_name, inviter_name, expires_at} and records the claim, or {ok:false, reason}.
--   not_inviter       the caller did not send this invitation
--   closed            the invitation is no longer pending (answered, cancelled or expired)
--   has_account       the person already has an account and sees the invite in the app
--   already_sent      this invitation was already emailed
--   recipient_limited this address was emailed an invitation within the last 7 days
--   sender_limited    the caller has emailed 15 invitations in the last 24 hours
CREATE OR REPLACE FUNCTION public.claim_group_invite_email(p_invitation_id BIGINT, p_user UUID) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE i split_group_invitations%ROWTYPE; v_group TEXT;
BEGIN
  SELECT * INTO i FROM split_group_invitations WHERE id = p_invitation_id FOR UPDATE;
  IF NOT FOUND OR i.invited_by IS DISTINCT FROM p_user THEN RETURN jsonb_build_object('ok', false, 'reason', 'not_inviter'); END IF;
  IF i.status <> 'pending' OR i.expires_at <= now() THEN RETURN jsonb_build_object('ok', false, 'reason', 'closed'); END IF;
  IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = i.email) THEN RETURN jsonb_build_object('ok', false, 'reason', 'has_account'); END IF;
  IF EXISTS (SELECT 1 FROM group_invite_emails WHERE invitation_id = i.id) THEN RETURN jsonb_build_object('ok', false, 'reason', 'already_sent'); END IF;
  IF EXISTS (SELECT 1 FROM group_invite_emails WHERE email = i.email AND sent_at > now() - interval '7 days') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'recipient_limited');
  END IF;
  IF (SELECT count(*) FROM group_invite_emails WHERE sent_by = p_user AND sent_at > now() - interval '1 day') >= 15 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'sender_limited');
  END IF;

  INSERT INTO group_invite_emails(invitation_id, email, sent_by) VALUES (i.id, i.email, p_user);
  SELECT name INTO v_group FROM split_groups WHERE id = i.group_id;
  RETURN jsonb_build_object('ok', true, 'email', i.email, 'group_name', v_group,
                            'inviter_name', public.inbox_display_name(p_user), 'expires_at', i.expires_at);
END $$;

-- If sending fails the claim is handed back so the person can try again.
CREATE OR REPLACE FUNCTION public.release_group_invite_email(p_invitation_id BIGINT) RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  DELETE FROM group_invite_emails WHERE invitation_id = p_invitation_id;
$$;
REVOKE ALL ON FUNCTION public.claim_group_invite_email(BIGINT, UUID) FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public.release_group_invite_email(BIGINT) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_group_invite_email(BIGINT, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.release_group_invite_email(BIGINT) TO service_role;
