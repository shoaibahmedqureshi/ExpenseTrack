-- One family per person, max 10 members (pending invitations count toward the cap).
CREATE UNIQUE INDEX IF NOT EXISTS uq_family_members_one_family ON public.family_members (user_id);

CREATE OR REPLACE FUNCTION public.enforce_family_group_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.family_members WHERE user_id = NEW.user_id)
     OR EXISTS (SELECT 1 FROM public.family_groups WHERE user_id = NEW.user_id) THEN
    RAISE EXCEPTION 'You are already in a family. Leave it before creating a new one.';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_family_group_insert ON public.family_groups;
CREATE TRIGGER trg_family_group_insert BEFORE INSERT ON public.family_groups
  FOR EACH ROW EXECUTE FUNCTION public.enforce_family_group_insert();

CREATE OR REPLACE FUNCTION public.enforce_family_member_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.family_members WHERE user_id = NEW.user_id AND family_id <> NEW.family_id) THEN
    RAISE EXCEPTION 'You are already in a family. Leave it before joining another one.';
  END IF;
  IF (SELECT count(*) FROM public.family_members WHERE family_id = NEW.family_id) >= 10 THEN
    RAISE EXCEPTION 'This family is full (10 members maximum).';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_family_member_insert ON public.family_members;
CREATE TRIGGER trg_family_member_insert BEFORE INSERT ON public.family_members
  FOR EACH ROW EXECUTE FUNCTION public.enforce_family_member_insert();

CREATE OR REPLACE FUNCTION public.enforce_family_invitation_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF (SELECT count(*) FROM public.family_members WHERE family_id = NEW.family_id)
   + (SELECT count(*) FROM public.family_invitations WHERE family_id = NEW.family_id AND status = 'pending') >= 10 THEN
    RAISE EXCEPTION 'This family has reached its 10 member limit (pending invitations count).';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_family_invitation_insert ON public.family_invitations;
CREATE TRIGGER trg_family_invitation_insert BEFORE INSERT ON public.family_invitations
  FOR EACH ROW EXECUTE FUNCTION public.enforce_family_invitation_insert();
