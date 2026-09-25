-- Expanded SEO Agent Tables for Forum Links, Comments, Profiles, and Reporting

-- Forum & Community Links
CREATE TABLE IF NOT EXISTS forum_opportunities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  forum_name text NOT NULL,
  forum_url text NOT NULL,
  category text, -- finance, budgeting, expense-tracking, etc.
  difficulty text, -- easy, medium, hard
  ranking_potential float, -- estimated DA impact
  status text DEFAULT 'discovered', -- discovered, posting_draft, posted, rejected
  link_anchor_text text,
  target_url text,
  post_date timestamp,
  post_url text,
  engagement_count integer DEFAULT 0,
  notes text,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  UNIQUE(forum_url, forum_name)
);

-- Profile Links (Stack Overflow, Quora, Medium, etc.)
CREATE TABLE IF NOT EXISTS profile_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  platform text NOT NULL, -- stackoverflow, quora, medium, dev.to, etc.
  platform_url text NOT NULL,
  profile_username text,
  profile_url text,
  bio text,
  status text DEFAULT 'planned', -- planned, created, active, paused
  creation_date timestamp,
  last_post_date timestamp,
  follower_count integer DEFAULT 0,
  content_count integer DEFAULT 0, -- posts/answers created
  engagement_metrics jsonb, -- {views: x, upvotes: y, comments: z}
  keywords_used text[], -- array of keywords in profile
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  UNIQUE(platform, profile_username)
);

-- Comments/Engagement Activities
CREATE TABLE IF NOT EXISTS comment_activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_url text NOT NULL, -- forum post, blog, stackoverflow question
  source_type text, -- forum, blog, q_a, social
  comment_text text,
  comment_url text,
  status text DEFAULT 'draft', -- draft, posted, approved, rejected
  posted_date timestamp,
  upvotes integer DEFAULT 0,
  replies integer DEFAULT 0,
  keywords_mentioned text[], -- keywords naturally included
  engagement_score float DEFAULT 0,
  notes text,
  created_at timestamp DEFAULT now(),
  UNIQUE(source_url, comment_text)
);

-- Daily SEO Activity Report
CREATE TABLE IF NOT EXISTS seo_daily_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_date date NOT NULL,
  activities_completed jsonb, -- {forum_posts: x, comments: y, profiles_created: z, guest_posts: w}
  links_created integer DEFAULT 0,
  estimated_da_impact float DEFAULT 0,
  keywords_targeted text[],
  opportunities_found integer DEFAULT 0,
  high_priority_opportunities integer DEFAULT 0,
  summary text, -- AI-generated summary of the day's work
  metrics jsonb, -- {total_posts: x, total_engagement: y, avg_upvotes: z}
  created_at timestamp DEFAULT now(),
  UNIQUE(report_date)
);

-- Weekly SEO Activity Report
CREATE TABLE IF NOT EXISTS seo_weekly_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start_date date NOT NULL,
  week_end_date date NOT NULL,
  total_activities integer DEFAULT 0,
  total_links_created integer DEFAULT 0,
  total_estimated_da_impact float DEFAULT 0,
  activities_breakdown jsonb, -- {forum_posts: {count: x, engagement: y}, comments: {...}, profiles: {...}}
  top_performing_content text, -- best engagement items
  keywords_performance jsonb, -- which keywords got best engagement
  profile_growth jsonb, -- follower/subscriber growth across profiles
  engagement_stats jsonb, -- upvotes, shares, comments totals
  recommendations text[], -- AI suggestions for next week
  summary text, -- comprehensive weekly summary
  created_at timestamp DEFAULT now(),
  UNIQUE(week_start_date)
);

-- SEO Activity Log (real-time tracking)
CREATE TABLE IF NOT EXISTS seo_activity_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_type text NOT NULL, -- forum_post, comment, profile_creation, link_building
  target_url text,
  keywords_used text[],
  status text, -- success, pending, failed
  error_message text,
  engagement_metric float DEFAULT 0,
  created_at timestamp DEFAULT now()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_forum_opportunities_status ON forum_opportunities(status);
CREATE INDEX IF NOT EXISTS idx_forum_opportunities_difficulty ON forum_opportunities(difficulty);
CREATE INDEX IF NOT EXISTS idx_profile_links_platform ON profile_links(platform);
CREATE INDEX IF NOT EXISTS idx_profile_links_status ON profile_links(status);
CREATE INDEX IF NOT EXISTS idx_comment_activities_status ON comment_activities(status);
CREATE INDEX IF NOT EXISTS idx_comment_activities_source ON comment_activities(source_type);
CREATE INDEX IF NOT EXISTS idx_seo_daily_reports_date ON seo_daily_reports(report_date);
CREATE INDEX IF NOT EXISTS idx_seo_weekly_reports_week ON seo_weekly_reports(week_start_date);
CREATE INDEX IF NOT EXISTS idx_seo_activity_log_type ON seo_activity_log(activity_type);
CREATE INDEX IF NOT EXISTS idx_seo_activity_log_created ON seo_activity_log(created_at);

-- Enable RLS
ALTER TABLE forum_opportunities ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE comment_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE seo_daily_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE seo_weekly_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE seo_activity_log ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Service role access
CREATE POLICY "seo_tables_service_role" ON forum_opportunities FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "seo_tables_service_role" ON profile_links FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "seo_tables_service_role" ON comment_activities FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "seo_tables_service_role" ON seo_daily_reports FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "seo_tables_service_role" ON seo_weekly_reports FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "seo_tables_service_role" ON seo_activity_log FOR ALL USING (auth.role() = 'service_role');
