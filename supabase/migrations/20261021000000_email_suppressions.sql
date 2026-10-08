-- People who asked us to stop emailing them. Written only by the opt-out function (service role).
CREATE TABLE IF NOT EXISTS public.email_suppressions (
  email TEXT NOT NULL CHECK (email = lower(email)),
  scope TEXT NOT NULL CHECK (scope IN ('group_invite')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (email, scope)
);
ALTER TABLE public.email_suppressions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.email_suppressions FROM anon, authenticated;

-- Same function as before with one more check: an address that opted out is never emailed again.
CREATE OR REPLACE FUNCTION public.claim_group_invite_email(p_invitation_id BIGINT, p_user UUID) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE i split_group_invitations%ROWTYPE; v_group TEXT;
BEGIN
  SELECT * INTO i FROM split_group_invitations WHERE id = p_invitation_id FOR UPDATE;
  IF NOT FOUND OR i.invited_by IS DISTINCT FROM p_user THEN RETURN jsonb_build_object('ok', false, 'reason', 'not_inviter'); END IF;
  IF i.status <> 'pending' OR i.expires_at <= now() THEN RETURN jsonb_build_object('ok', false, 'reason', 'closed'); END IF;
  IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = i.email) THEN RETURN jsonb_build_object('ok', false, 'reason', 'has_account'); END IF;
  IF EXISTS (SELECT 1 FROM email_suppressions WHERE email = i.email AND scope = 'group_invite') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'opted_out');
  END IF;
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
REVOKE ALL ON FUNCTION public.claim_group_invite_email(BIGINT, UUID) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_group_invite_email(BIGINT, UUID) TO service_role;
