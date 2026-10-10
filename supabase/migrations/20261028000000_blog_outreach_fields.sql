-- Guest-post targets: every contact must come from the blog's own pages, and pitches stay drafts until reviewed.
alter table public.link_opportunities
  add column if not exists blog_name text,
  add column if not exists topic text,
  add column if not exists guidelines_url text,
  add column if not exists page_summary text,
  add column if not exists email_status text not null default 'unverified',
  add column if not exists email_source text,
  add column if not exists email_verified_at timestamptz,
  add column if not exists verify_attempted_at timestamptz,
  add column if not exists verify_note text,
  add column if not exists source_query text;

alter table public.link_opportunities
  drop constraint if exists link_opportunities_email_status_check,
  add constraint link_opportunities_email_status_check
    check (email_status in ('unverified', 'verified', 'not_found'));

-- Anything stored before this existed was never checked.
update public.link_opportunities set email = null where email is not null and email_status = 'unverified';

alter table public.guest_post_pitches
  add column if not exists products text[] not null default '{}',
  add column if not exists subject text;
