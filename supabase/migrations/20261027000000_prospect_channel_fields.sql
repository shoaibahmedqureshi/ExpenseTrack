-- YouTube prospects: keep the public channel text we read emails and links from.
alter table public.influencer_prospects
  add column if not exists channel_url text,
  add column if not exists bio text;
