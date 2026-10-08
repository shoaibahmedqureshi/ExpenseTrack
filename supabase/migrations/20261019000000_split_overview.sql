-- One call that says where you stand in every family and group you belong to, for the dashboard.

-- Net position of one person in one ledger (positive = is owed money). Mirrors the app's calculator.
CREATE OR REPLACE FUNCTION public.ledger_net(p_kind TEXT, p_id BIGINT, p_user UUID) RETURNS NUMERIC
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    COALESCE((SELECT sum(sh.amount) FROM expense_splits s JOIN expense_split_shares sh ON sh.split_id = s.id
               WHERE (CASE p_kind WHEN 'family' THEN s.family_id ELSE s.group_id END) = p_id
                 AND s.paid_by = p_user AND sh.user_id <> p_user), 0)
  - COALESCE((SELECT sum(sh.amount) FROM expense_splits s JOIN expense_split_shares sh ON sh.split_id = s.id
               WHERE (CASE p_kind WHEN 'family' THEN s.family_id ELSE s.group_id END) = p_id
                 AND sh.user_id = p_user AND s.paid_by <> p_user), 0)
  + COALESCE((SELECT sum(amount) FROM expense_settlements
               WHERE (CASE p_kind WHEN 'family' THEN family_id ELSE group_id END) = p_id AND from_user = p_user), 0)
  - COALESCE((SELECT sum(amount) FROM expense_settlements
               WHERE (CASE p_kind WHEN 'family' THEN family_id ELSE group_id END) = p_id AND to_user = p_user), 0);
$$;
REVOKE ALL ON FUNCTION public.ledger_net(TEXT, BIGINT, UUID) FROM public, anon, authenticated;

-- One definition of "net" for groups too.
CREATE OR REPLACE FUNCTION public.group_net(p_group_id BIGINT, p_user UUID) RETURNS NUMERIC
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.ledger_net('group', p_group_id, p_user);
$$;

CREATE OR REPLACE FUNCTION public.my_split_overview() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY abs(x.net) DESC, x.name), '[]'::jsonb) FROM (
    SELECT 'family'::text AS kind, f.id, f.name,
           public.ledger_net('family', f.id, auth.uid()) AS net,
           (EXISTS (SELECT 1 FROM expense_splits WHERE family_id = f.id)
            OR EXISTS (SELECT 1 FROM expense_settlements WHERE family_id = f.id)) AS has_activity
      FROM family_groups f WHERE f.id IN (SELECT public.my_family_ids())
    UNION ALL
    SELECT 'group'::text, g.id, g.name,
           public.ledger_net('group', g.id, auth.uid()),
           (EXISTS (SELECT 1 FROM expense_splits WHERE group_id = g.id)
            OR EXISTS (SELECT 1 FROM expense_settlements WHERE group_id = g.id))
      FROM split_groups g WHERE g.id IN (SELECT public.my_group_ids())
  ) x;
$$;
REVOKE ALL ON FUNCTION public.my_split_overview() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.my_split_overview() TO authenticated;
