-- In-app inbox: rows are created by triggers (never by clients) and read by their owner.
CREATE TABLE IF NOT EXISTS public.inbox_notifications (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_inbox_user_created ON public.inbox_notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inbox_unread ON public.inbox_notifications(user_id) WHERE read_at IS NULL;

ALTER TABLE public.inbox_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Read own notifications" ON public.inbox_notifications;
CREATE POLICY "Read own notifications" ON public.inbox_notifications FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Mark own notifications read" ON public.inbox_notifications;
CREATE POLICY "Mark own notifications read" ON public.inbox_notifications FOR UPDATE
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "Delete own notifications" ON public.inbox_notifications;
CREATE POLICY "Delete own notifications" ON public.inbox_notifications FOR DELETE USING (user_id = auth.uid());

REVOKE ALL ON public.inbox_notifications FROM authenticated;
GRANT SELECT, DELETE ON public.inbox_notifications TO authenticated;
GRANT UPDATE (read_at) ON public.inbox_notifications TO authenticated;

-- Helpers (security definer: they read other users' names and write other users' rows).
CREATE OR REPLACE FUNCTION public.inbox_display_name(uid UUID) RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(NULLIF(btrim(p.name), ''), split_part(u.email, '@', 1), 'Someone')
  FROM auth.users u LEFT JOIN public.profiles p ON p.id = u.id WHERE u.id = uid;
$$;

CREATE OR REPLACE FUNCTION public.inbox_money(a NUMERIC) RETURNS TEXT
LANGUAGE sql IMMUTABLE AS $$ SELECT '$' || to_char(a, 'FM999,999,990.00'); $$;

CREATE OR REPLACE FUNCTION public.inbox_notify(uid UUID, t TEXT, ttl TEXT, msg TEXT, d JSONB) RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  INSERT INTO inbox_notifications(user_id, type, title, body, data) VALUES (uid, t, ttl, msg, COALESCE(d, '{}'::jsonb));
$$;
REVOKE ALL ON FUNCTION public.inbox_notify(UUID, TEXT, TEXT, TEXT, JSONB) FROM public, authenticated;
REVOKE ALL ON FUNCTION public.inbox_display_name(UUID) FROM public, authenticated;

-- 1. Someone adds a split that includes you.
CREATE OR REPLACE FUNCTION public.trg_inbox_split_share() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE s RECORD;
BEGIN
  SELECT * INTO s FROM expense_splits WHERE id = NEW.split_id;
  IF s.id IS NULL OR NEW.user_id = s.created_by THEN RETURN NEW; END IF;
  PERFORM inbox_notify(
    NEW.user_id, 'split_added', 'New split: ' || s.description,
    inbox_display_name(s.created_by) || ' added a split. ' ||
      CASE WHEN NEW.user_id = s.paid_by THEN 'You paid ' || inbox_money(s.total_amount) || '.'
           ELSE 'Your share is ' || inbox_money(NEW.amount) || '.' END,
    jsonb_build_object('family_id', s.family_id, 'split_id', s.id));
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_inbox_split_share ON public.expense_split_shares;
CREATE TRIGGER trg_inbox_split_share AFTER INSERT ON public.expense_split_shares
  FOR EACH ROW EXECUTE FUNCTION public.trg_inbox_split_share();

-- 2. A payment is recorded between you and someone else (notify the other party).
CREATE OR REPLACE FUNCTION public.trg_inbox_settlement() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.created_by = NEW.from_user THEN
    PERFORM inbox_notify(NEW.to_user, 'payment_recorded', 'Payment received',
      inbox_display_name(NEW.created_by) || ' recorded a payment of ' || inbox_money(NEW.amount) || ' to you.',
      jsonb_build_object('family_id', NEW.family_id, 'settlement_id', NEW.id));
  ELSE
    PERFORM inbox_notify(NEW.from_user, 'payment_recorded', 'Payment confirmed',
      inbox_display_name(NEW.created_by) || ' marked ' || inbox_money(NEW.amount) || ' as received from you.',
      jsonb_build_object('family_id', NEW.family_id, 'settlement_id', NEW.id));
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_inbox_settlement ON public.expense_settlements;
CREATE TRIGGER trg_inbox_settlement AFTER INSERT ON public.expense_settlements
  FOR EACH ROW EXECUTE FUNCTION public.trg_inbox_settlement();

-- 3. You are invited to a family (only if the invited email already has an account).
CREATE OR REPLACE FUNCTION public.trg_inbox_invitation() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE invitee UUID; fam TEXT;
BEGIN
  SELECT id INTO invitee FROM auth.users WHERE lower(email) = lower(NEW.email) LIMIT 1;
  IF invitee IS NULL OR invitee = NEW.invited_by THEN RETURN NEW; END IF;
  SELECT name INTO fam FROM family_groups WHERE id = NEW.family_id;
  PERFORM inbox_notify(invitee, 'family_invite', 'Family invitation',
    COALESCE(inbox_display_name(NEW.invited_by), 'Someone') || ' invited you to join ' || COALESCE(fam, 'a family') || '.',
    jsonb_build_object('family_id', NEW.family_id, 'invitation_id', NEW.id));
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_inbox_invitation ON public.family_invitations;
CREATE TRIGGER trg_inbox_invitation AFTER INSERT ON public.family_invitations
  FOR EACH ROW EXECUTE FUNCTION public.trg_inbox_invitation();

-- 4. Someone joins your family (notify the owner).
CREATE OR REPLACE FUNCTION public.trg_inbox_member_joined() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE owner UUID;
BEGIN
  SELECT user_id INTO owner FROM family_groups WHERE id = NEW.family_id;
  IF owner IS NULL OR owner = NEW.user_id THEN RETURN NEW; END IF;
  PERFORM inbox_notify(owner, 'member_joined', inbox_display_name(NEW.user_id) || ' joined your family',
    inbox_display_name(NEW.user_id) || ' accepted your invitation.',
    jsonb_build_object('family_id', NEW.family_id, 'user_id', NEW.user_id));
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_inbox_member_joined ON public.family_members;
CREATE TRIGGER trg_inbox_member_joined AFTER INSERT ON public.family_members
  FOR EACH ROW EXECUTE FUNCTION public.trg_inbox_member_joined();

-- Live updates for the bell badge.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'inbox_notifications') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.inbox_notifications;
  END IF;
END $$;
