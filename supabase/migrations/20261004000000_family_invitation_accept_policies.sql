-- Let an invitee read the family they were invited to and join it.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'family_groups' AND policyname = 'Invitees can view invited family') THEN
    CREATE POLICY "Invitees can view invited family" ON public.family_groups FOR SELECT USING (
      id IN (SELECT family_id FROM public.family_invitations
             WHERE lower(email) = lower(auth.jwt() ->> 'email') AND status = 'pending')
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'family_members' AND policyname = 'Invitees can join via invitation') THEN
    CREATE POLICY "Invitees can join via invitation" ON public.family_members FOR INSERT WITH CHECK (
      user_id = auth.uid()
      AND family_id IN (SELECT family_id FROM public.family_invitations
                        WHERE lower(email) = lower(auth.jwt() ->> 'email') AND status = 'pending'
                          AND expires_at > now())
    );
  END IF;
END $$;
