-- Server-side record of who holds which paid plan, so a family can be tied to its admin's MAX.
--
-- Until now a plan was only ever worked out on each phone from StoreKit / Play, so the server could not tell
-- whether a family's admin still pays. Rows here are written only by edge functions (sync-entitlement, and the
-- Apple / Google webhooks keeping them current); each is verified against the store, never taken from the client.
--
-- Nothing in this migration changes behaviour: family_is_active() returns true for every family until the
-- 'family_requires_max' flag is switched on (see 20261101000001_family_requires_max.sql for the enforcement).

create table if not exists public.user_entitlements (
  user_id                 uuid primary key references public.profiles(id) on delete cascade,
  plan                    text not null check (plan in ('pro_monthly', 'pro_annual', 'max_monthly', 'max_annual')),
  store                   text not null check (store in ('apple', 'google')),
  -- Apple: originalTransactionId. Google: the purchase token. Stable across renewals, so webhooks can find the row.
  original_transaction_id text not null,
  product_id              text not null,
  expires_at              timestamptz not null,
  updated_at              timestamptz not null default now(),
  unique (store, original_transaction_id)
);

alter table public.user_entitlements enable row level security;

create policy "Users read own entitlement" on public.user_entitlements
  for select using (auth.uid() = user_id);
-- No insert/update/delete policies on purpose: only the service role (edge functions) writes here.

create table if not exists public.feature_flags (
  key        text primary key,
  enabled    boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.feature_flags enable row level security;
-- No policies: read only through the security-definer functions below.

insert into public.feature_flags (key, enabled) values ('family_requires_max', false)
  on conflict (key) do nothing;

create or replace function public.family_requires_max_enabled()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select enabled from feature_flags where key = 'family_requires_max'), false);
$$;

create or replace function public.is_entitled_max(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from user_entitlements
     where user_id = p_user and starts_with(plan, 'max_') and expires_at > now());
$$;

-- A family is active while the enforcement flag is off, or while its owner holds a current MAX entitlement.
create or replace function public.family_is_active(p_family_id bigint)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when not public.family_requires_max_enabled() then true
    else exists (select 1 from family_groups g where g.id = p_family_id and public.is_entitled_max(g.user_id))
  end;
$$;

-- What the app asks to decide whether to show a family or a "ask the admin to renew" screen.
create or replace function public.family_access(p_family_id bigint)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid; v_expires timestamptz;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  select user_id into v_owner from family_groups where id = p_family_id;
  if v_owner is null then return jsonb_build_object('exists', false, 'active', false); end if;
  if v_owner <> auth.uid()
     and not exists (select 1 from family_members where family_id = p_family_id and user_id = auth.uid()) then
    raise exception 'You are not a member of this family';
  end if;
  select expires_at into v_expires from user_entitlements where user_id = v_owner and starts_with(plan, 'max_');
  return jsonb_build_object(
    'exists', true,
    'active', public.family_is_active(p_family_id),
    'is_owner', v_owner = auth.uid(),
    'admin_max_expires_at', v_expires);
end $$;

revoke all on function public.family_requires_max_enabled() from public, anon, authenticated;
revoke all on function public.is_entitled_max(uuid) from public, anon, authenticated;
revoke all on function public.family_is_active(bigint) from public, anon, authenticated;
revoke all on function public.family_access(bigint) from public, anon;
grant execute on function public.family_access(bigint) to authenticated;
