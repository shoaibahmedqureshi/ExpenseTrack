-- Family owner can remove other members and change their role; a member can leave.
CREATE OR REPLACE FUNCTION public.i_own_family(fid bigint)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.family_groups WHERE id = fid AND user_id = auth.uid());
$$;
REVOKE ALL ON FUNCTION public.i_own_family(bigint) FROM public;
GRANT EXECUTE ON FUNCTION public.i_own_family(bigint) TO authenticated;

DROP POLICY IF EXISTS "Owner can remove members" ON public.family_members;
CREATE POLICY "Owner can remove members" ON public.family_members FOR DELETE
  USING (public.i_own_family(family_id) AND user_id <> auth.uid());

DROP POLICY IF EXISTS "Members can leave family" ON public.family_members;
CREATE POLICY "Members can leave family" ON public.family_members FOR DELETE
  USING (user_id = auth.uid() AND NOT public.i_own_family(family_id));

DROP POLICY IF EXISTS "Owner can change member roles" ON public.family_members;
CREATE POLICY "Owner can change member roles" ON public.family_members FOR UPDATE
  USING (public.i_own_family(family_id) AND user_id <> auth.uid())
  WITH CHECK (public.i_own_family(family_id) AND user_id <> auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.family_members TO authenticated;
