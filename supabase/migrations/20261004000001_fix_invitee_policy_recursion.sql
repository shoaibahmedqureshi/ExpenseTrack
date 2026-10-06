-- Avoid RLS recursion between family_groups and family_invitations.
CREATE OR REPLACE FUNCTION public.pending_invite_family_ids()
RETURNS SETOF bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT family_id FROM public.family_invitations
  WHERE lower(email) = lower(auth.jwt() ->> 'email')
    AND status = 'pending' AND expires_at > now();
$$;
REVOKE ALL ON FUNCTION public.pending_invite_family_ids() FROM public;
GRANT EXECUTE ON FUNCTION public.pending_invite_family_ids() TO authenticated;

DROP POLICY IF EXISTS "Invitees can view invited family" ON public.family_groups;
CREATE POLICY "Invitees can view invited family" ON public.family_groups FOR SELECT
  USING (id IN (SELECT public.pending_invite_family_ids()));

DROP POLICY IF EXISTS "Invitees can join via invitation" ON public.family_members;
CREATE POLICY "Invitees can join via invitation" ON public.family_members FOR INSERT
  WITH CHECK (user_id = auth.uid() AND family_id IN (SELECT public.pending_invite_family_ids()));
