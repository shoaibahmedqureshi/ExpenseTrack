-- 1. Remove duplicate memberships (same user joined the same family repeatedly), keep the oldest.
DELETE FROM public.family_members a
USING public.family_members b
WHERE a.family_id = b.family_id AND a.user_id = b.user_id AND a.id > b.id;

-- 2. Prevent them from happening again.
CREATE UNIQUE INDEX IF NOT EXISTS uq_family_members_family_user
  ON public.family_members (family_id, user_id);

-- Only one open invitation per family + email (case-insensitive).
UPDATE public.family_invitations a SET status = 'expired'
FROM public.family_invitations b
WHERE a.status = 'pending' AND b.status = 'pending'
  AND a.family_id = b.family_id AND lower(a.email) = lower(b.email) AND a.id > b.id;
CREATE UNIQUE INDEX IF NOT EXISTS uq_family_invitations_pending
  ON public.family_invitations (family_id, lower(email)) WHERE status = 'pending';

-- 3. Let members see their family and the other members (security definer avoids RLS recursion).
CREATE OR REPLACE FUNCTION public.my_family_ids()
RETURNS SETOF bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT family_id FROM public.family_members WHERE user_id = auth.uid();
$$;
REVOKE ALL ON FUNCTION public.my_family_ids() FROM public;
GRANT EXECUTE ON FUNCTION public.my_family_ids() TO authenticated;

DROP POLICY IF EXISTS "Members can view their family" ON public.family_groups;
CREATE POLICY "Members can view their family" ON public.family_groups FOR SELECT
  USING (id IN (SELECT public.my_family_ids()));

DROP POLICY IF EXISTS "Members can view family members" ON public.family_members;
CREATE POLICY "Members can view family members" ON public.family_members FOR SELECT
  USING (family_id IN (SELECT public.my_family_ids()));
