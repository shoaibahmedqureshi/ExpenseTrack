-- ── Influencer revenue-share tracking ──────────────────────────────────
-- Attributes a subscription purchase to the influencer code used, via
-- Apple App Store Server Notifications V2 and Google Play Real-time
-- Developer Notifications (RTDN). Both webhooks are server-to-server —
-- neither store pushes this data to a client, so it has to land here.

-- One row per influencer relationship. `platform_offer_id` is the
-- Apple subscription offer code identifier or the Google Play offer ID —
-- whichever the code was created under — used to match an incoming
-- notification back to the influencer.
create table if not exists public.influencer_codes (
  id                    bigserial primary key,
  influencer_name       text not null,
  contact_email         text,
  platform              text not null check (platform in ('ios', 'android')),
  platform_offer_id     text not null,
  revenue_share_percent numeric(5,2) not null default 20.00,
  active                boolean not null default true,
  created_at            timestamptz not null default now(),
  unique (platform, platform_offer_id)
);

alter table public.influencer_codes enable row level security;
-- No client policies at all — this table is managed only via the
-- dashboard/service role. Regular users have no reason to read or write
-- influencer/payout data.

-- One row per attributed purchase event. Deliberately keyed on
-- (platform, transaction_id) rather than just user_id, since a renewal
-- produces a new transaction_id and we want each billing period tracked
-- separately for payout accuracy.
create table if not exists public.subscription_referrals (
  id                 bigserial primary key,
  influencer_code_id bigint not null references public.influencer_codes(id) on delete cascade,
  user_id            uuid references public.profiles(id) on delete set null,
  platform           text not null check (platform in ('ios', 'android')),
  product_id         text not null,
  transaction_id     text not null,
  event_type         text not null, -- e.g. SUBSCRIBED, DID_RENEW, offer redemption
  purchase_amount    numeric(12,2),
  currency           text,
  payout_amount      numeric(12,2),
  payout_status      text not null default 'pending' check (payout_status in ('pending', 'paid', 'void')),
  raw_notification   jsonb,
  created_at         timestamptz not null default now(),
  unique (platform, transaction_id)
);

alter table public.subscription_referrals enable row level security;
-- Same as above — service-role only, no client-facing policies.

create index if not exists idx_subscription_referrals_code
  on public.subscription_referrals(influencer_code_id);
