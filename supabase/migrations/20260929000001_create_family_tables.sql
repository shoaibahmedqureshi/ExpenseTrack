-- ============================================================
-- Family Management Tables
-- ============================================================

-- Family Groups table
CREATE TABLE IF NOT EXISTS public.family_groups (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Family Members table
CREATE TABLE IF NOT EXISTS public.family_members (
  id BIGSERIAL PRIMARY KEY,
  family_id BIGINT NOT NULL REFERENCES public.family_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'member',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Family Invitations table
CREATE TABLE IF NOT EXISTS public.family_invitations (
  id BIGSERIAL PRIMARY KEY,
  family_id BIGINT NOT NULL REFERENCES public.family_groups(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'member',
  token TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_family_groups_user_id ON public.family_groups(user_id);
CREATE INDEX IF NOT EXISTS idx_family_members_family_id ON public.family_members(family_id);
CREATE INDEX IF NOT EXISTS idx_family_members_user_id ON public.family_members(user_id);
CREATE INDEX IF NOT EXISTS idx_family_invitations_family_id ON public.family_invitations(family_id);
CREATE INDEX IF NOT EXISTS idx_family_invitations_email ON public.family_invitations(email);

-- Enable RLS
ALTER TABLE public.family_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_invitations ENABLE ROW LEVEL SECURITY;

-- RLS Policies for family_groups
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'family_groups' AND policyname = 'Users can view own families') THEN
    CREATE POLICY "Users can view own families" ON public.family_groups FOR SELECT USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'family_groups' AND policyname = 'Users can create families') THEN
    CREATE POLICY "Users can create families" ON public.family_groups FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'family_groups' AND policyname = 'Users can update own families') THEN
    CREATE POLICY "Users can update own families" ON public.family_groups FOR UPDATE USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'family_groups' AND policyname = 'Users can delete own families') THEN
    CREATE POLICY "Users can delete own families" ON public.family_groups FOR DELETE USING (auth.uid() = user_id);
  END IF;
END $$;

-- RLS Policies for family_members
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'family_members' AND policyname = 'Users can view family members') THEN
    CREATE POLICY "Users can view family members" ON public.family_members FOR SELECT USING (
      family_id IN (SELECT id FROM public.family_groups WHERE user_id = auth.uid()) OR user_id = auth.uid()
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'family_members' AND policyname = 'Admins can add members') THEN
    CREATE POLICY "Admins can add members" ON public.family_members FOR INSERT WITH CHECK (
      family_id IN (SELECT family_groups.id FROM public.family_groups WHERE user_id = auth.uid())
    );
  END IF;
END $$;

-- RLS Policies for family_invitations
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'family_invitations' AND policyname = 'Users can view own invitations') THEN
    CREATE POLICY "Users can view own invitations" ON public.family_invitations FOR SELECT USING (email = auth.jwt() ->> 'email');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'family_invitations' AND policyname = 'Admins can create invitations') THEN
    CREATE POLICY "Admins can create invitations" ON public.family_invitations FOR INSERT WITH CHECK (
      family_id IN (SELECT family_groups.id FROM public.family_groups WHERE user_id = auth.uid())
    );
  END IF;
END $$;
