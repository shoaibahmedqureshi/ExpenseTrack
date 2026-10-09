-- Create influencer_revenue table
CREATE TABLE IF NOT EXISTS public.influencer_revenue (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  family_id BIGINT REFERENCES public.family_groups(id) ON DELETE SET NULL,
  influencer_code TEXT NOT NULL,
  subscription_plan TEXT NOT NULL,
  revenue_amount NUMERIC(10,2) NOT NULL,
  currency TEXT DEFAULT 'PKR',
  transaction_date TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_influencer_revenue_user_date
ON public.influencer_revenue(user_id, transaction_date DESC);

CREATE INDEX IF NOT EXISTS idx_influencer_revenue_code
ON public.influencer_revenue(influencer_code);

CREATE INDEX IF NOT EXISTS idx_influencer_revenue_user_code
ON public.influencer_revenue(user_id, influencer_code);

-- Enable RLS
ALTER TABLE public.influencer_revenue ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only view their own revenue
CREATE POLICY "Users can view own revenue"
ON public.influencer_revenue
FOR SELECT
USING (auth.uid() = user_id);

-- RLS Policy: Users can only insert their own revenue
CREATE POLICY "Users can insert own revenue"
ON public.influencer_revenue
FOR INSERT
WITH CHECK (auth.uid() = user_id);

