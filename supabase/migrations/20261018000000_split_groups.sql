-- Split groups: share expenses with people outside your family (a trip, a flat, friends).
-- Free for everyone. A group holds up to 20 people (pending invitations count). All writes go through
-- the functions below; clients only read.

CREATE TABLE IF NOT EXISTS public.split_groups (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 60),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.split_group_members (
  group_id BIGINT NOT NULL REFERENCES public.split_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner','member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_split_group_members_user ON public.split_group_members(user_id);

CREATE TABLE IF NOT EXISTS public.split_group_invitations (
  id BIGSERIAL PRIMARY KEY,
  group_id BIGINT NOT NULL REFERENCES public.split_groups(id) ON DELETE CASCADE,
  email TEXT NOT NULL CHECK (email = lower(email) AND length(email) BETWEEN 5 AND 200),
  invited_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined','cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '14 days'),
  responded_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_split_group_invite_pending ON public.split_group_invitations (group_id, email) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_split_group_invite_email ON public.split_group_invitations (email) WHERE status = 'pending';

ALTER TABLE public.split_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_group_invitations ENABLE ROW LEVEL SECURITY;

-- ── Helpers (security definer so policies never recurse) ──────────────
CREATE OR REPLACE FUNCTION public.my_group_ids() RETURNS SETOF BIGINT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT group_id FROM public.split_group_members WHERE user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.i_own_group(gid BIGINT) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.split_group_members WHERE group_id = gid AND user_id = auth.uid() AND role = 'owner');
$$;

CREATE OR REPLACE FUNCTION public.my_email() RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT lower(email) FROM auth.users WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.pending_group_invite_group_ids() RETURNS SETOF BIGINT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT group_id FROM public.split_group_invitations
   WHERE status = 'pending' AND expires_at > now() AND email = public.my_email();
$$;
REVOKE ALL ON FUNCTION public.my_group_ids(), public.i_own_group(BIGINT), public.my_email(), public.pending_group_invite_group_ids() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.my_group_ids(), public.i_own_group(BIGINT), public.my_email(), public.pending_group_invite_group_ids() TO authenticated;

-- ── Reads only ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Members and invitees read group" ON public.split_groups;
CREATE POLICY "Members and invitees read group" ON public.split_groups FOR SELECT
  USING (id IN (SELECT public.my_group_ids()) OR id IN (SELECT public.pending_group_invite_group_ids()));
DROP POLICY IF EXISTS "Members read group members" ON public.split_group_members;
CREATE POLICY "Members read group members" ON public.split_group_members FOR SELECT
  USING (group_id IN (SELECT public.my_group_ids()));
DROP POLICY IF EXISTS "Members and invitee read invitations" ON public.split_group_invitations;
CREATE POLICY "Members and invitee read invitations" ON public.split_group_invitations FOR SELECT
  USING (group_id IN (SELECT public.my_group_ids()) OR email = public.my_email());

REVOKE ALL ON public.split_groups, public.split_group_members, public.split_group_invitations FROM anon, authenticated;
GRANT SELECT ON public.split_groups, public.split_group_members, public.split_group_invitations TO authenticated;

-- ── Splits and settlements can now belong to a group instead of a family ──
ALTER TABLE public.expense_splits ALTER COLUMN family_id DROP NOT NULL;
ALTER TABLE public.expense_splits ADD COLUMN IF NOT EXISTS group_id BIGINT REFERENCES public.split_groups(id) ON DELETE CASCADE;
ALTER TABLE public.expense_settlements ALTER COLUMN family_id DROP NOT NULL;
ALTER TABLE public.expense_settlements ADD COLUMN IF NOT EXISTS group_id BIGINT REFERENCES public.split_groups(id) ON DELETE CASCADE;
ALTER TABLE public.expense_splits DROP CONSTRAINT IF EXISTS expense_splits_one_scope;
ALTER TABLE public.expense_splits ADD CONSTRAINT expense_splits_one_scope CHECK (num_nonnulls(family_id, group_id) = 1);
ALTER TABLE public.expense_settlements DROP CONSTRAINT IF EXISTS expense_settlements_one_scope;
ALTER TABLE public.expense_settlements ADD CONSTRAINT expense_settlements_one_scope CHECK (num_nonnulls(family_id, group_id) = 1);
CREATE INDEX IF NOT EXISTS idx_expense_splits_group ON public.expense_splits(group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_expense_settlements_group ON public.expense_settlements(group_id, created_at DESC);

DROP POLICY IF EXISTS "Members read splits" ON public.expense_splits;
CREATE POLICY "Members read splits" ON public.expense_splits FOR SELECT
  USING (family_id IN (SELECT public.my_family_ids()) OR group_id IN (SELECT public.my_group_ids()));
DROP POLICY IF EXISTS "Members read shares" ON public.expense_split_shares;
CREATE POLICY "Members read shares" ON public.expense_split_shares FOR SELECT
  USING (split_id IN (SELECT id FROM public.expense_splits
                       WHERE family_id IN (SELECT public.my_family_ids()) OR group_id IN (SELECT public.my_group_ids())));
DROP POLICY IF EXISTS "Members read settlements" ON public.expense_settlements;
CREATE POLICY "Members read settlements" ON public.expense_settlements FOR SELECT
  USING (family_id IN (SELECT public.my_family_ids()) OR group_id IN (SELECT public.my_group_ids()));
DROP POLICY IF EXISTS "Creator or owner deletes split" ON public.expense_splits;
CREATE POLICY "Creator or owner deletes split" ON public.expense_splits FOR DELETE
  USING (created_by = auth.uid()
         OR (family_id IS NOT NULL AND public.i_own_family(family_id))
         OR (group_id IS NOT NULL AND public.i_own_group(group_id)));
DROP POLICY IF EXISTS "Creator or owner deletes settlement" ON public.expense_settlements;
CREATE POLICY "Creator or owner deletes settlement" ON public.expense_settlements FOR DELETE
  USING (created_by = auth.uid()
         OR (family_id IS NOT NULL AND public.i_own_family(family_id))
         OR (group_id IS NOT NULL AND public.i_own_group(group_id)));

-- ── Ledger helpers: a "ledger" is either a family or a group ──────────
CREATE OR REPLACE FUNCTION public.ledger_has_member(p_kind TEXT, p_id BIGINT, p_user UUID) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT CASE p_kind
    WHEN 'family' THEN EXISTS (SELECT 1 FROM family_members WHERE family_id = p_id AND user_id = p_user)
    WHEN 'group'  THEN EXISTS (SELECT 1 FROM split_group_members WHERE group_id = p_id AND user_id = p_user)
    ELSE false END;
$$;
REVOKE ALL ON FUNCTION public.ledger_has_member(TEXT, BIGINT, UUID) FROM public, anon, authenticated;

-- Net position of one person in a group: positive = is owed money. Mirrors the app's calculator.
CREATE OR REPLACE FUNCTION public.group_net(p_group_id BIGINT, p_user UUID) RETURNS NUMERIC
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    COALESCE((SELECT sum(sh.amount) FROM expense_splits s JOIN expense_split_shares sh ON sh.split_id = s.id
               WHERE s.group_id = p_group_id AND s.paid_by = p_user AND sh.user_id <> p_user), 0)
  - COALESCE((SELECT sum(sh.amount) FROM expense_splits s JOIN expense_split_shares sh ON sh.split_id = s.id
               WHERE s.group_id = p_group_id AND sh.user_id = p_user AND s.paid_by <> p_user), 0)
  + COALESCE((SELECT sum(amount) FROM expense_settlements WHERE group_id = p_group_id AND from_user = p_user), 0)
  - COALESCE((SELECT sum(amount) FROM expense_settlements WHERE group_id = p_group_id AND to_user = p_user), 0);
$$;
REVOKE ALL ON FUNCTION public.group_net(BIGINT, UUID) FROM public, anon, authenticated;

-- One create-split and one record-settlement function for both kinds of ledger.
CREATE OR REPLACE FUNCTION public.create_ledger_split(
  p_kind TEXT, p_id BIGINT, p_paid_by UUID, p_description TEXT,
  p_total NUMERIC, p_split_type TEXT, p_shares JSONB
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id BIGINT; v_sum NUMERIC; v_n INT; v_distinct INT; s JSONB;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF p_kind NOT IN ('family','group') THEN RAISE EXCEPTION 'Unknown ledger type'; END IF;
  IF NOT public.ledger_has_member(p_kind, p_id, auth.uid()) THEN RAISE EXCEPTION 'You are not a member of this %', p_kind; END IF;
  IF NOT public.ledger_has_member(p_kind, p_id, p_paid_by) THEN RAISE EXCEPTION 'The person who paid is not in this %', p_kind; END IF;
  IF p_split_type NOT IN ('equal','amount','percent') THEN RAISE EXCEPTION 'Unknown split type'; END IF;
  IF p_total IS NULL OR p_total <= 0 THEN RAISE EXCEPTION 'Total must be greater than zero'; END IF;
  IF length(btrim(coalesce(p_description,''))) NOT BETWEEN 1 AND 120 THEN RAISE EXCEPTION 'Add a short description'; END IF;
  IF jsonb_typeof(p_shares) <> 'array' OR jsonb_array_length(p_shares) = 0 THEN
    RAISE EXCEPTION 'Choose at least one person to split with';
  END IF;

  SELECT count(*), count(DISTINCT x->>'user_id'), COALESCE(sum(round((x->>'amount')::numeric, 2)), 0)
    INTO v_n, v_distinct, v_sum FROM jsonb_array_elements(p_shares) x;
  IF v_n <> v_distinct THEN RAISE EXCEPTION 'A person appears twice in the split'; END IF;
  IF v_sum <> round(p_total, 2) THEN RAISE EXCEPTION 'Shares (%) do not add up to the total (%)', v_sum, round(p_total, 2); END IF;

  FOR s IN SELECT * FROM jsonb_array_elements(p_shares) LOOP
    IF NOT public.ledger_has_member(p_kind, p_id, (s->>'user_id')::uuid) THEN
      RAISE EXCEPTION 'Everyone in the split must be a member of this %', p_kind;
    END IF;
    IF (s->>'amount')::numeric < 0 THEN RAISE EXCEPTION 'Amounts cannot be negative'; END IF;
  END LOOP;

  INSERT INTO expense_splits(family_id, group_id, paid_by, created_by, description, total_amount, split_type)
    VALUES (CASE WHEN p_kind = 'family' THEN p_id END, CASE WHEN p_kind = 'group' THEN p_id END,
            p_paid_by, auth.uid(), btrim(p_description), round(p_total, 2), p_split_type)
    RETURNING id INTO v_id;

  INSERT INTO expense_split_shares(split_id, user_id, amount, percent)
    SELECT v_id, (x->>'user_id')::uuid, round((x->>'amount')::numeric, 2), NULLIF(x->>'percent','')::numeric
    FROM jsonb_array_elements(p_shares) x;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.record_ledger_settlement(p_kind TEXT, p_id BIGINT, p_from UUID, p_to UUID, p_amount NUMERIC)
RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id BIGINT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF p_kind NOT IN ('family','group') THEN RAISE EXCEPTION 'Unknown ledger type'; END IF;
  IF auth.uid() NOT IN (p_from, p_to) THEN RAISE EXCEPTION 'You can only record payments you made or received'; END IF;
  IF p_from = p_to THEN RAISE EXCEPTION 'Choose two different people'; END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be greater than zero'; END IF;
  IF NOT (public.ledger_has_member(p_kind, p_id, p_from) AND public.ledger_has_member(p_kind, p_id, p_to)) THEN
    RAISE EXCEPTION 'Both people must be members of this %', p_kind;
  END IF;
  INSERT INTO expense_settlements(family_id, group_id, from_user, to_user, amount, created_by)
    VALUES (CASE WHEN p_kind = 'family' THEN p_id END, CASE WHEN p_kind = 'group' THEN p_id END,
            p_from, p_to, round(p_amount, 2), auth.uid()) RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.create_ledger_split(TEXT, BIGINT, UUID, TEXT, NUMERIC, TEXT, JSONB) FROM public, anon;
REVOKE ALL ON FUNCTION public.record_ledger_settlement(TEXT, BIGINT, UUID, UUID, NUMERIC) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.create_ledger_split(TEXT, BIGINT, UUID, TEXT, NUMERIC, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_ledger_settlement(TEXT, BIGINT, UUID, UUID, NUMERIC) TO authenticated;

-- ── Group management ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_split_group(p_name TEXT) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id BIGINT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF length(btrim(coalesce(p_name,''))) NOT BETWEEN 1 AND 60 THEN RAISE EXCEPTION 'Give the group a name (up to 60 characters)'; END IF;
  IF (SELECT count(*) FROM split_groups WHERE created_by = auth.uid()) >= 20 THEN
    RAISE EXCEPTION 'You have created the maximum of 20 groups';
  END IF;
  INSERT INTO split_groups(name, created_by) VALUES (btrim(p_name), auth.uid()) RETURNING id INTO v_id;
  INSERT INTO split_group_members(group_id, user_id, email, role) VALUES (v_id, auth.uid(), public.my_email(), 'owner');
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.rename_split_group(p_group_id BIGINT, p_name TEXT) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.i_own_group(p_group_id) THEN RAISE EXCEPTION 'Only the group owner can rename it'; END IF;
  IF length(btrim(coalesce(p_name,''))) NOT BETWEEN 1 AND 60 THEN RAISE EXCEPTION 'Give the group a name (up to 60 characters)'; END IF;
  UPDATE split_groups SET name = btrim(p_name) WHERE id = p_group_id;
END $$;

CREATE OR REPLACE FUNCTION public.invite_to_split_group(p_group_id BIGINT, p_email TEXT) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_email TEXT := lower(btrim(coalesce(p_email,'')));
  v_id BIGINT; v_name TEXT; v_uid UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF NOT EXISTS (SELECT 1 FROM split_group_members WHERE group_id = p_group_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'You are not a member of this group';
  END IF;
  IF v_email !~ '^[^\s@<>"'',;]+@[^\s@<>"'',;]+\.[A-Za-z]{2,}$' THEN RAISE EXCEPTION 'Enter a valid email address'; END IF;
  IF v_email = public.my_email() THEN RAISE EXCEPTION 'You are already in this group'; END IF;
  IF EXISTS (SELECT 1 FROM split_group_members WHERE group_id = p_group_id AND lower(email) = v_email) THEN
    RAISE EXCEPTION 'That person is already in this group';
  END IF;
  IF EXISTS (SELECT 1 FROM split_group_invitations WHERE group_id = p_group_id AND email = v_email AND status = 'pending' AND expires_at > now()) THEN
    RAISE EXCEPTION 'That person already has a pending invitation';
  END IF;
  -- Expired pending invitations stop counting and stop blocking a new one.
  UPDATE split_group_invitations SET status = 'cancelled', responded_at = now()
   WHERE group_id = p_group_id AND email = v_email AND status = 'pending' AND expires_at <= now();
  IF (SELECT count(*) FROM split_group_members WHERE group_id = p_group_id)
   + (SELECT count(*) FROM split_group_invitations WHERE group_id = p_group_id AND status = 'pending' AND expires_at > now()) >= 20 THEN
    RAISE EXCEPTION 'This group has reached its 20 person limit (pending invitations count)';
  END IF;
  IF (SELECT count(*) FROM split_group_invitations WHERE invited_by = auth.uid() AND created_at > now() - interval '1 day') >= 30 THEN
    RAISE EXCEPTION 'You have sent a lot of invitations today. Please try again tomorrow';
  END IF;

  INSERT INTO split_group_invitations(group_id, email, invited_by) VALUES (p_group_id, v_email, auth.uid()) RETURNING id INTO v_id;

  SELECT name INTO v_name FROM split_groups WHERE id = p_group_id;
  SELECT id INTO v_uid FROM auth.users WHERE lower(email) = v_email;
  IF v_uid IS NOT NULL THEN
    PERFORM inbox_notify(v_uid, 'group_invite', 'Group invitation',
      inbox_display_name(auth.uid()) || ' invited you to the group "' || v_name || '".',
      jsonb_build_object('group_id', p_group_id, 'invitation_id', v_id));
  END IF;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.respond_to_group_invitation(p_invitation_id BIGINT, p_accept BOOLEAN) RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE i split_group_invitations%ROWTYPE; v_name TEXT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  SELECT * INTO i FROM split_group_invitations WHERE id = p_invitation_id FOR UPDATE;
  IF NOT FOUND OR i.email <> public.my_email() THEN RAISE EXCEPTION 'Invitation not found'; END IF;
  IF i.status <> 'pending' THEN RAISE EXCEPTION 'This invitation has already been answered'; END IF;
  IF i.expires_at <= now() THEN
    UPDATE split_group_invitations SET status = 'cancelled', responded_at = now() WHERE id = i.id;
    RAISE EXCEPTION 'This invitation has expired. Ask them to invite you again';
  END IF;

  IF NOT p_accept THEN
    UPDATE split_group_invitations SET status = 'declined', responded_at = now() WHERE id = i.id;
    RETURN 'declined';
  END IF;

  IF (SELECT count(*) FROM split_group_members WHERE group_id = i.group_id) >= 20 THEN
    RAISE EXCEPTION 'This group is full';
  END IF;
  INSERT INTO split_group_members(group_id, user_id, email, role) VALUES (i.group_id, auth.uid(), i.email, 'member')
    ON CONFLICT DO NOTHING;
  UPDATE split_group_invitations SET status = 'accepted', responded_at = now() WHERE id = i.id;

  SELECT name INTO v_name FROM split_groups WHERE id = i.group_id;
  IF i.invited_by IS NOT NULL AND i.invited_by <> auth.uid() THEN
    PERFORM inbox_notify(i.invited_by, 'group_member_joined', 'Joined your group',
      inbox_display_name(auth.uid()) || ' joined "' || v_name || '".',
      jsonb_build_object('group_id', i.group_id));
  END IF;
  RETURN 'accepted';
END $$;

CREATE OR REPLACE FUNCTION public.cancel_group_invitation(p_invitation_id BIGINT) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE i split_group_invitations%ROWTYPE;
BEGIN
  SELECT * INTO i FROM split_group_invitations WHERE id = p_invitation_id FOR UPDATE;
  IF NOT FOUND OR i.status <> 'pending' THEN RAISE EXCEPTION 'Invitation not found'; END IF;
  IF i.invited_by IS DISTINCT FROM auth.uid() AND NOT public.i_own_group(i.group_id) THEN
    RAISE EXCEPTION 'Only the person who invited them, or the group owner, can cancel this';
  END IF;
  UPDATE split_group_invitations SET status = 'cancelled', responded_at = now() WHERE id = i.id;
END $$;

-- Someone with an unsettled balance cannot leave or be removed: that would erase a debt.
CREATE OR REPLACE FUNCTION public.assert_settled(p_group_id BIGINT, p_user UUID) RETURNS VOID
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF abs(public.group_net(p_group_id, p_user)) >= 0.005 THEN
    RAISE EXCEPTION 'Settle up first: this person still has an unsettled balance in the group';
  END IF;
END $$;
REVOKE ALL ON FUNCTION public.assert_settled(BIGINT, UUID) FROM public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.leave_split_group(p_group_id BIGINT) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE me split_group_members%ROWTYPE; v_next UUID;
BEGIN
  SELECT * INTO me FROM split_group_members WHERE group_id = p_group_id AND user_id = auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'You are not in this group'; END IF;
  PERFORM public.assert_settled(p_group_id, auth.uid());
  IF me.role = 'owner' THEN
    SELECT user_id INTO v_next FROM split_group_members WHERE group_id = p_group_id AND user_id <> auth.uid() ORDER BY joined_at LIMIT 1;
    IF v_next IS NOT NULL THEN UPDATE split_group_members SET role = 'owner' WHERE group_id = p_group_id AND user_id = v_next; END IF;
  END IF;
  DELETE FROM split_group_members WHERE group_id = p_group_id AND user_id = auth.uid();
  -- The last person out closes the group (its settled ledger goes with it).
  IF NOT EXISTS (SELECT 1 FROM split_group_members WHERE group_id = p_group_id) THEN
    DELETE FROM split_groups WHERE id = p_group_id;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.remove_group_member(p_group_id BIGINT, p_user UUID) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.i_own_group(p_group_id) THEN RAISE EXCEPTION 'Only the group owner can remove people'; END IF;
  IF p_user = auth.uid() THEN RAISE EXCEPTION 'Use Leave group to leave'; END IF;
  PERFORM public.assert_settled(p_group_id, p_user);
  DELETE FROM split_group_members WHERE group_id = p_group_id AND user_id = p_user;
END $$;

CREATE OR REPLACE FUNCTION public.delete_split_group(p_group_id BIGINT) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE m UUID;
BEGIN
  IF NOT public.i_own_group(p_group_id) THEN RAISE EXCEPTION 'Only the group owner can delete the group'; END IF;
  FOR m IN SELECT user_id FROM split_group_members WHERE group_id = p_group_id LOOP
    PERFORM public.assert_settled(p_group_id, m);
  END LOOP;
  DELETE FROM split_groups WHERE id = p_group_id;
END $$;

-- Members with names, for display. Names live in profiles, which other users cannot read directly.
CREATE OR REPLACE FUNCTION public.list_group_members(p_group_id BIGINT) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM split_group_members WHERE group_id = p_group_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'You are not a member of this group';
  END IF;
  RETURN coalesce((SELECT jsonb_agg(jsonb_build_object(
      'user_id', m.user_id, 'email', m.email, 'role', m.role, 'joined_at', m.joined_at,
      'name', nullif(btrim(p.name), '')) ORDER BY m.joined_at)
    FROM split_group_members m LEFT JOIN profiles p ON p.id = m.user_id WHERE m.group_id = p_group_id), '[]'::jsonb);
END $$;

DO $$
DECLARE f TEXT;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'create_split_group(text)', 'rename_split_group(bigint,text)', 'invite_to_split_group(bigint,text)',
    'respond_to_group_invitation(bigint,boolean)', 'cancel_group_invitation(bigint)', 'leave_split_group(bigint)',
    'remove_group_member(bigint,uuid)', 'delete_split_group(bigint)', 'list_group_members(bigint)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM public, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
END $$;

-- ── Notifications mention group splits too ────────────────────────────
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
    jsonb_build_object('family_id', s.family_id, 'group_id', s.group_id, 'split_id', s.id));
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.trg_inbox_settlement() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.created_by = NEW.from_user THEN
    PERFORM inbox_notify(NEW.to_user, 'payment_recorded', 'Payment received',
      inbox_display_name(NEW.created_by) || ' recorded a payment of ' || inbox_money(NEW.amount) || ' to you.',
      jsonb_build_object('family_id', NEW.family_id, 'group_id', NEW.group_id, 'settlement_id', NEW.id));
  ELSE
    PERFORM inbox_notify(NEW.from_user, 'payment_recorded', 'Payment confirmed',
      inbox_display_name(NEW.created_by) || ' marked ' || inbox_money(NEW.amount) || ' as received from you.',
      jsonb_build_object('family_id', NEW.family_id, 'group_id', NEW.group_id, 'settlement_id', NEW.id));
  END IF;
  RETURN NEW;
END $$;
