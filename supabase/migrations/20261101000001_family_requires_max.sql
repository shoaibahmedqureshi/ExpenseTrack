-- Ties a family to its admin's MAX plan. Every guard below is a no-op while the 'family_requires_max' flag is off
-- (family_is_active() is then always true), so this can be applied ahead of switching enforcement on.
--
-- When the admin's MAX ends: members lose family data and actions, nothing is deleted (renewing restores it all), and
-- the admin keeps access to their own family so they can see the renew prompt. The admin cannot invite or create
-- families, enforced here and not only in the app.
--
-- To enforce:   update public.feature_flags set enabled = true, updated_at = now() where key = 'family_requires_max';
-- To roll back: set enabled = false.

-- All the 'Members read ...' policies on shared family data go through this one function.
create or replace function public.my_family_ids()
returns setof bigint
language sql stable security definer set search_path to 'public' as $function$
  select family_id from public.family_members
   where user_id = auth.uid()
     and (public.family_is_active(family_id) or public.i_own_family(family_id));
$function$;

-- Split ledgers (families and groups) check membership here. Groups are unaffected.
create or replace function public.ledger_has_member(p_kind text, p_id bigint, p_user uuid)
returns boolean
language sql stable security definer set search_path to 'public' as $function$
  select case p_kind
    when 'family' then exists (select 1 from family_members where family_id = p_id and user_id = p_user)
                       and (public.family_is_active(p_id)
                            or exists (select 1 from family_groups where id = p_id and user_id = p_user))
    when 'group'  then exists (select 1 from split_group_members where group_id = p_id and user_id = p_user)
    else false end;
$function$;

-- create_expense_split: refuse for an inactive family.
CREATE OR REPLACE FUNCTION public.create_expense_split(p_family_id bigint, p_paid_by uuid, p_description text, p_total numeric, p_split_type text, p_shares jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id BIGINT; v_sum NUMERIC; v_n INT; v_distinct INT; s JSONB;
BEGIN
  IF NOT public.family_is_active(p_family_id) AND NOT public.i_own_family(p_family_id) THEN
    RAISE EXCEPTION 'This family is inactive. Ask the family admin to renew MAX.';
  END IF;
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF NOT EXISTS (SELECT 1 FROM family_members WHERE family_id = p_family_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'You are not a member of this family';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM family_members WHERE family_id = p_family_id AND user_id = p_paid_by) THEN
    RAISE EXCEPTION 'The person who paid is not in this family';
  END IF;
  IF p_split_type NOT IN ('equal','amount','percent') THEN RAISE EXCEPTION 'Unknown split type'; END IF;
  IF p_total IS NULL OR p_total <= 0 THEN RAISE EXCEPTION 'Total must be greater than zero'; END IF;
  IF jsonb_typeof(p_shares) <> 'array' OR jsonb_array_length(p_shares) = 0 THEN
    RAISE EXCEPTION 'Choose at least one person to split with';
  END IF;

  SELECT count(*), count(DISTINCT x->>'user_id'), COALESCE(sum(round((x->>'amount')::numeric, 2)), 0)
    INTO v_n, v_distinct, v_sum FROM jsonb_array_elements(p_shares) x;
  IF v_n <> v_distinct THEN RAISE EXCEPTION 'A person appears twice in the split'; END IF;
  IF v_sum <> round(p_total, 2) THEN RAISE EXCEPTION 'Shares (%) do not add up to the total (%)', v_sum, round(p_total, 2); END IF;

  FOR s IN SELECT * FROM jsonb_array_elements(p_shares) LOOP
    IF NOT EXISTS (SELECT 1 FROM family_members WHERE family_id = p_family_id AND user_id = (s->>'user_id')::uuid) THEN
      RAISE EXCEPTION 'Everyone in the split must be a family member';
    END IF;
    IF (s->>'amount')::numeric < 0 THEN RAISE EXCEPTION 'Amounts cannot be negative'; END IF;
  END LOOP;

  INSERT INTO expense_splits(family_id, paid_by, created_by, description, total_amount, split_type)
    VALUES (p_family_id, p_paid_by, auth.uid(), btrim(p_description), round(p_total, 2), p_split_type)
    RETURNING id INTO v_id;

  INSERT INTO expense_split_shares(split_id, user_id, amount, percent)
    SELECT v_id, (x->>'user_id')::uuid, round((x->>'amount')::numeric, 2), NULLIF(x->>'percent','')::numeric
    FROM jsonb_array_elements(p_shares) x;

  RETURN v_id;
END $function$;

-- record_settlement: refuse for an inactive family.
CREATE OR REPLACE FUNCTION public.record_settlement(p_family_id bigint, p_from uuid, p_to uuid, p_amount numeric)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_id BIGINT;
BEGIN
  IF NOT public.family_is_active(p_family_id) AND NOT public.i_own_family(p_family_id) THEN
    RAISE EXCEPTION 'This family is inactive. Ask the family admin to renew MAX.';
  END IF;
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF auth.uid() NOT IN (p_from, p_to) THEN RAISE EXCEPTION 'You can only record payments you made or received'; END IF;
  IF p_from = p_to THEN RAISE EXCEPTION 'Choose two different people'; END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be greater than zero'; END IF;
  IF (SELECT count(*) FROM family_members WHERE family_id = p_family_id AND user_id IN (p_from, p_to)) <> 2 THEN
    RAISE EXCEPTION 'Both people must be members of this family';
  END IF;
  INSERT INTO expense_settlements(family_id, from_user, to_user, amount, created_by)
    VALUES (p_family_id, p_from, p_to, round(p_amount, 2), auth.uid()) RETURNING id INTO v_id;
  RETURN v_id;
END $function$;

-- publish_spending_summary: refuse for an inactive family.
CREATE OR REPLACE FUNCTION public.publish_spending_summary(p_family_id bigint, p_from date, p_rows jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE r JSONB;
BEGIN
  IF NOT public.family_is_active(p_family_id) AND NOT public.i_own_family(p_family_id) THEN
    RAISE EXCEPTION 'This family is inactive. Ask the family admin to renew MAX.';
  END IF;
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF NOT EXISTS (SELECT 1 FROM family_sharing WHERE family_id = p_family_id AND user_id = auth.uid() AND enabled)
     OR NOT EXISTS (SELECT 1 FROM family_members WHERE family_id = p_family_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Spending sharing is not turned on for you';
  END IF;
  IF p_from IS NULL OR p_from <> date_trunc('month', p_from)::date THEN RAISE EXCEPTION 'p_from must be the first day of a month'; END IF;
  IF jsonb_typeof(p_rows) <> 'array' OR jsonb_array_length(p_rows) > 200 THEN RAISE EXCEPTION 'Too many rows'; END IF;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    IF (r->>'month')::date < p_from THEN RAISE EXCEPTION 'Row before p_from'; END IF;
  END LOOP;

  DELETE FROM family_spending_summaries WHERE family_id = p_family_id AND user_id = auth.uid() AND month >= p_from;

  INSERT INTO family_spending_summaries(family_id, user_id, month, category, spent)
    SELECT p_family_id, auth.uid(), (x->>'month')::date, btrim(x->>'category'), sum(round((x->>'spent')::numeric, 2))
      FROM jsonb_array_elements(p_rows) x
     GROUP BY (x->>'month')::date, btrim(x->>'category')
  ON CONFLICT (family_id, user_id, month, category) DO UPDATE SET spent = EXCLUDED.spent, updated_at = now();
  UPDATE family_sharing SET updated_at = now() WHERE family_id = p_family_id AND user_id = auth.uid();
END $function$;

-- set_spending_sharing: refuse for an inactive family.
CREATE OR REPLACE FUNCTION public.set_spending_sharing(p_family_id bigint, p_enabled boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.family_is_active(p_family_id) AND NOT public.i_own_family(p_family_id) THEN
    RAISE EXCEPTION 'This family is inactive. Ask the family admin to renew MAX.';
  END IF;
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF NOT EXISTS (SELECT 1 FROM family_members WHERE family_id = p_family_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'You are not a member of this family';
  END IF;
  INSERT INTO family_sharing(family_id, user_id, enabled, updated_at)
    VALUES (p_family_id, auth.uid(), COALESCE(p_enabled, false), now())
  ON CONFLICT (family_id, user_id) DO UPDATE SET enabled = EXCLUDED.enabled, updated_at = now();
  IF NOT COALESCE(p_enabled, false) THEN
    DELETE FROM family_spending_summaries WHERE family_id = p_family_id AND user_id = auth.uid();
  END IF;
END $function$;

-- household_overview: refuse for an inactive family.
CREATE OR REPLACE FUNCTION public.household_overview(p_family_id bigint, p_month date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_month DATE := date_trunc('month', coalesce(p_month, current_date))::date;
BEGIN
  IF NOT public.family_is_active(p_family_id) AND NOT public.i_own_family(p_family_id) THEN
    RAISE EXCEPTION 'This family is inactive. Ask the family admin to renew MAX.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM family_members WHERE family_id = p_family_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'You are not a member of this family';
  END IF;
  RETURN jsonb_build_object(
    'month', v_month,
    'members', coalesce((SELECT jsonb_agg(jsonb_build_object(
        'user_id', m.user_id,
        'name', public.inbox_display_name(m.user_id),
        'email', m.email,
        'is_owner', (m.role = 'admin'),
        'sharing', coalesce(fs.enabled, false),
        'categories', CASE WHEN coalesce(fs.enabled, false) THEN coalesce((
            SELECT jsonb_agg(jsonb_build_object('category', s.category, 'spent', s.spent) ORDER BY s.spent DESC)
              FROM family_spending_summaries s
             WHERE s.family_id = m.family_id AND s.user_id = m.user_id AND s.month = v_month), '[]'::jsonb)
          ELSE '[]'::jsonb END
      ) ORDER BY m.joined_at)
      FROM family_members m LEFT JOIN family_sharing fs ON fs.family_id = m.family_id AND fs.user_id = m.user_id
     WHERE m.family_id = p_family_id), '[]'::jsonb),
    'budgets', coalesce((SELECT jsonb_agg(jsonb_build_object('category', b.category, 'amount', b.amount) ORDER BY b.category NULLS FIRST)
                           FROM family_budgets b WHERE b.family_id = p_family_id), '[]'::jsonb)
  );
END $function$;

-- Creating a family, inviting and adding members need an active MAX plan once enforcement is on.
CREATE OR REPLACE FUNCTION public.enforce_family_group_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF public.family_requires_max_enabled() AND NOT public.is_entitled_max(NEW.user_id) THEN
    RAISE EXCEPTION 'Creating a family needs an active MAX plan.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.family_members WHERE user_id = NEW.user_id)
     OR EXISTS (SELECT 1 FROM public.family_groups WHERE user_id = NEW.user_id) THEN
    RAISE EXCEPTION 'You are already in a family. Leave it before creating a new one.';
  END IF;
  RETURN NEW;
END $function$;

CREATE OR REPLACE FUNCTION public.enforce_family_invitation_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.family_is_active(NEW.family_id) THEN
    RAISE EXCEPTION 'Inviting people needs an active MAX plan.';
  END IF;
  IF (SELECT count(*) FROM public.family_members WHERE family_id = NEW.family_id)
   + (SELECT count(*) FROM public.family_invitations WHERE family_id = NEW.family_id AND status = 'pending') >= 10 THEN
    RAISE EXCEPTION 'This family has reached its 10 member limit (pending invitations count).';
  END IF;
  RETURN NEW;
END $function$;

CREATE OR REPLACE FUNCTION public.enforce_family_member_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.family_is_active(NEW.family_id) THEN
    RAISE EXCEPTION 'This family is inactive. Ask the family admin to renew MAX.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.family_members WHERE user_id = NEW.user_id AND family_id <> NEW.family_id) THEN
    RAISE EXCEPTION 'You are already in a family. Leave it before joining another one.';
  END IF;
  IF (SELECT count(*) FROM public.family_members WHERE family_id = NEW.family_id) >= 10 THEN
    RAISE EXCEPTION 'This family is full (10 members maximum).';
  END IF;
  RETURN NEW;
END $function$;

