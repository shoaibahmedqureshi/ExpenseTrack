-- Target blogs with roughly 1k-50k monthly visitors, using the figure the blog publishes itself.
alter table public.link_opportunities
  add column if not exists claimed_monthly_visitors integer,
  add column if not exists traffic_source text,
  add column if not exists traffic_fit text not null default 'unknown';

alter table public.link_opportunities
  drop constraint if exists link_opportunities_traffic_fit_check,
  add constraint link_opportunities_traffic_fit_check check (traffic_fit in ('unknown', 'in_range', 'out_of_range'));

-- Quality screen: skip paid-link networks and thin sites.
alter table public.link_opportunities
  add column if not exists quality_status text not null default 'unchecked',
  add column if not exists quality_flags text[] not null default '{}';

alter table public.link_opportunities
  drop constraint if exists link_opportunities_quality_status_check,
  add constraint link_opportunities_quality_status_check check (quality_status in ('unchecked', 'ok', 'suspect'));
