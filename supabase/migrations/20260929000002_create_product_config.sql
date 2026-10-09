-- Product configuration table for agents
CREATE TABLE IF NOT EXISTS product_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_slug text UNIQUE NOT NULL,
  product_name text NOT NULL,
  description text NOT NULL,
  long_description text,

  -- Target audience & niches
  target_niches text[] NOT NULL, -- Array of niche keywords
  target_platforms text[] NOT NULL, -- ['tiktok', 'instagram', 'youtube']
  target_audience_description text,

  -- Use cases
  primary_use_cases text[] NOT NULL,
  secondary_use_cases text[],

  -- Partnership offer
  offer_title text NOT NULL,
  offer_description text NOT NULL,
  offer_value text, -- e.g., "1 year free premium for 5 users"
  revenue_share_percentage numeric,

  -- Agent settings
  min_follower_count integer DEFAULT 1000,
  min_engagement_rate numeric DEFAULT 0.02,
  ideal_fit_score integer DEFAULT 8, -- Score threshold for auto-approval

  -- Status
  is_active boolean DEFAULT true,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

-- Indexes
CREATE INDEX idx_product_config_slug ON product_config(product_slug);
CREATE INDEX idx_product_config_active ON product_config(is_active);

-- Enable RLS
ALTER TABLE product_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "product_config_service_role_all" ON product_config
  FOR ALL USING (auth.role() = 'service_role');

-- Seed product data
INSERT INTO product_config (
  product_slug,
  product_name,
  description,
  long_description,
  target_niches,
  target_platforms,
  target_audience_description,
  primary_use_cases,
  secondary_use_cases,
  offer_title,
  offer_description,
  offer_value,
  min_follower_count,
  min_engagement_rate,
  ideal_fit_score,
  is_active
) VALUES
(
  'stitchify',
  'Stitchify',
  'Screenshot joining app that combines multiple screenshots into one seamless image',
  'Stitchify helps creators, developers, designers, and content creators combine multiple screenshots into professional-looking composite images. Perfect for tutorials, comparisons, UI showcases, and visual explanations.',
  ARRAY[
    'tech reviews',
    'software tutorials',
    'ui/ux design',
    'app development',
    'programming',
    'web design',
    'before/after comparisons',
    'product reviews',
    'screenshot guides',
    'step-by-step tutorials',
    'content creation',
    'design inspiration'
  ],
  ARRAY['tiktok', 'youtube', 'instagram'],
  'Tech-savvy creators, developers, designers, and tutorial creators who frequently use screenshots for educational or comparison content.',
  ARRAY[
    'Creating step-by-step tutorials with screenshot combinations',
    'Comparing UI/UX designs side-by-side',
    'Showcasing before/after transformations visually',
    'Creating composite screenshots for app reviews',
    'Demonstrating software features through screenshots',
    'Building visual guides for developers'
  ],
  ARRAY[
    'Social proof with screenshot galleries',
    'Content repurposing across platforms',
    'Creating Instagram carousels from screenshots'
  ],
  'Free Premium Access + Revenue Share',
  '1 year free Stitchify Premium (up to 5 users) + 20% revenue share on referred subscriptions',
  '1 year free premium + 20% revenue share',
  5000,
  0.05,
  8,
  true
),
(
  'outlay',
  'Outlay',
  'Personal finance & expense tracking app for managing budgets and financial goals',
  'Outlay is a comprehensive expense tracking app that helps users manage their finances, track spending, set budgets, and achieve financial goals. Perfect for personal finance content creators.',
  ARRAY[
    'personal finance',
    'budgeting',
    'expense tracking',
    'financial literacy',
    'money management',
    'financial goals',
    'saving tips',
    'investing basics',
    'lifestyle content'
  ],
  ARRAY['tiktok', 'youtube', 'instagram'],
  'Personal finance enthusiasts, budgeting-focused creators, lifestyle influencers, and financial literacy educators.',
  ARRAY[
    'Teaching budgeting strategies',
    'Sharing money-saving tips',
    'Demonstrating expense tracking workflows',
    'Creating financial literacy content',
    'Showcasing wealth-building techniques'
  ],
  ARRAY[
    'Personal finance education',
    'Lifestyle content featuring financial wellness'
  ],
  'Free Pro Subscription + Revenue Share',
  '1 year free Outlay Pro (up to 5 users) + 15% revenue share on referred subscriptions',
  '1 year free pro + 15% revenue share',
  3000,
  0.03,
  7,
  true
);
