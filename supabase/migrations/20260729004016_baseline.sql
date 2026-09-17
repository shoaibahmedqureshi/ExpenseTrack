-- ============================================================
-- ExpenseTrack — Supabase schema
-- Run this once in: Supabase dashboard → SQL Editor → New query
-- ============================================================

-- ── Profiles ────────────────────────────────────────────────
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  name          text,
  currency      text not null default 'USD',
  avatar_url    text,
  onboarding_done boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- Auto-create a profile row when a user signs up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, name)
  values (new.id, new.raw_user_meta_data->>'full_name');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── Categories ───────────────────────────────────────────────
create table if not exists public.categories (
  id         bigserial primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  name       text not null,
  icon_key   text not null,
  color      bigint not null,
  created_at timestamptz not null default now()
);

-- ── Expenses ─────────────────────────────────────────────────
create table if not exists public.expenses (
  id          bigserial primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  local_id    integer,          -- SQLite row id on the originating device
  title       text not null,
  amount      numeric(12,2) not null,
  date        timestamptz not null,
  type        integer not null, -- 0 = income, 1 = expense
  category_id bigint references public.categories(id) on delete set null,
  note        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ── Budgets ──────────────────────────────────────────────────
create table if not exists public.budgets (
  id          bigserial primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  local_id    integer,          -- SQLite row id on the originating device
  category_id bigint references public.categories(id) on delete set null,
  month       date not null,    -- first day of the budgeted month
  amount      numeric(12,2) not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ── Row Level Security ───────────────────────────────────────
alter table public.profiles  enable row level security;
alter table public.categories enable row level security;
alter table public.expenses  enable row level security;
alter table public.budgets   enable row level security;

-- Profiles: users can read, insert, and update only their own row.
-- INSERT is normally covered by the handle_new_user trigger (SECURITY
-- DEFINER, bypasses RLS), but this policy is required so the app's own
-- upsert-on-signup doesn't depend on that trigger having already run.
create policy "profiles_select" on public.profiles for select using (auth.uid() = id);
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

-- Categories: full CRUD on own rows. WITH CHECK is explicit (rather than
-- relying on Postgres reusing USING for inserts) so this can't silently
-- regress into an "insert anyone's user_id" hole if the policy is ever
-- split into per-command policies later.
create policy "categories_all" on public.categories for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Expenses: full CRUD on own rows.
create policy "expenses_all" on public.expenses for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Budgets: full CRUD on own rows.
create policy "budgets_all" on public.budgets for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── Indexes ──────────────────────────────────────────────────
create index if not exists idx_expenses_user   on public.expenses(user_id);
create index if not exists idx_expenses_date   on public.expenses(date desc);
create index if not exists idx_categories_user on public.categories(user_id);
create index if not exists idx_budgets_user    on public.budgets(user_id);
create index if not exists idx_budgets_month   on public.budgets(month desc);

-- ── OCR debug logs (testing only — KAN-9 receipt scanner accuracy) ──
-- Populated only by debug builds (kDebugMode) so real Play Store users
-- never have receipt text uploaded here. Safe to drop once KAN-9 closes.
create table if not exists public.ocr_debug_logs (
  id          bigserial primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  raw_text    text not null,
  merchant    text,
  total       numeric(12,2),
  tax         numeric(12,2),
  scan_date   timestamptz,
  created_at  timestamptz not null default now()
);

alter table public.ocr_debug_logs enable row level security;
-- App writes/edits only its own rows (normal authenticated session).
create policy "ocr_debug_logs_own" on public.ocr_debug_logs for all using (auth.uid() = user_id);
-- Lets the anon key (already public — it ships in the app) read this
-- table so scans can be checked without a live device connection.
-- Testing-only table; drop this policy (or the table) once KAN-9 closes.
create policy "ocr_debug_logs_select_anon" on public.ocr_debug_logs for select to anon using (true);

create index if not exists idx_ocr_debug_logs_user on public.ocr_debug_logs(user_id);
create index if not exists idx_ocr_debug_logs_created on public.ocr_debug_logs(created_at desc);

-- ── Budget debug logs (testing only — "budget shows 0 spent" investigation) ──
-- Snapshots the exact local state (all categories incl. any duplicates,
-- all budgets, and the computed spend-per-category map) the instant the
-- Budget screen loads, so a real device's actual data shape can be
-- inspected directly instead of guessed at. Not gated by kDebugMode since
-- this is specifically for debugging the release build under test — drop
-- this table once the bug is confirmed fixed.
create table if not exists public.budget_debug_logs (
  id            bigserial primary key,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  device_id     text,
  month         text not null,
  categories    jsonb not null,
  budgets       jsonb not null,
  spent_by_cat  jsonb not null,
  created_at    timestamptz not null default now()
);

alter table public.budget_debug_logs enable row level security;
create policy "budget_debug_logs_own" on public.budget_debug_logs for all using (auth.uid() = user_id);
-- Lets the anon key (already public — it ships in the app) read this
-- table so it can be checked without a live device connection.
create policy "budget_debug_logs_select_anon" on public.budget_debug_logs for select to anon using (true);

create index if not exists idx_budget_debug_logs_user on public.budget_debug_logs(user_id);
create index if not exists idx_budget_debug_logs_created on public.budget_debug_logs(created_at desc);

-- ── Sync debug logs (testing only — "budget does not sync across devices" investigation) ──
-- One row per SyncService.run() attempt, on every device, capturing what
-- actually happened during push/pull (counts, success/failure, the error
-- if any) plus how many budgets exist locally right after — so a stalled
-- or silently-failing sync on either device is directly visible instead
-- of guessed at. Not gated by kDebugMode. Drop once the bug is confirmed
-- fixed.
create table if not exists public.sync_debug_logs (
  id                   bigserial primary key,
  user_id              uuid not null references public.profiles(id) on delete cascade,
  device_id            text,
  attempt              int not null,
  succeeded            boolean not null,
  error                text,
  categories_pushed    int not null default 0,
  expenses_pushed      int not null default 0,
  budgets_pushed       int not null default 0,
  categories_pulled    int not null default 0,
  expenses_pulled      int not null default 0,
  budgets_pulled       int not null default 0,
  budgets_local_total  int,
  created_at           timestamptz not null default now()
);

alter table public.sync_debug_logs enable row level security;
create policy "sync_debug_logs_own" on public.sync_debug_logs for all using (auth.uid() = user_id);
create policy "sync_debug_logs_select_anon" on public.sync_debug_logs for select to anon using (true);

create index if not exists idx_sync_debug_logs_user on public.sync_debug_logs(user_id);
create index if not exists idx_sync_debug_logs_created on public.sync_debug_logs(created_at desc);

-- ── Migration: expenses.tax (run against an existing database) ──────
-- Informational breakdown of `amount` (which already includes tax) —
-- never added to it. Populated from the receipt scanner's separate tax
-- extraction, or left null for manual entries / older rows.
alter table public.expenses add column if not exists tax numeric(12,2);

-- ── Scan counts (server-side enforcement of the free-tier monthly limit) ──
-- Moved off-device (was SharedPreferences, see SubscriptionService) because
-- a local-only counter resets on uninstall/reinstall or is simply absent on
-- a second device — trivial to bypass. One row per user per calendar
-- month, incremented only through increment_scan_count() below so the
-- limit can't be raised by a client just upserting its own row.
create table if not exists public.scan_counts (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  month      text not null,  -- 'YYYY-MM'
  count      int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, month)
);

alter table public.scan_counts enable row level security;
-- Read-only for the owning user — lets the client show "X scans left"
-- without a round trip through the RPC. All writes go through the
-- SECURITY DEFINER function below; there is deliberately no insert/update
-- policy here, so a client can't bypass the limit by writing its own row.
create policy "scan_counts_select_own" on public.scan_counts
  for select using (auth.uid() = user_id);

-- Atomically increments this month's count and reports whether the scan
-- was allowed. SECURITY DEFINER so the write itself isn't gated by a
-- client-writable policy; `for update` locks the row so two devices
-- scanning at the same moment can't both read count=29 and both proceed.
create or replace function public.increment_scan_count(p_limit int)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_month   text := to_char(now(), 'YYYY-MM');
  v_count   int;
  v_allowed boolean;
begin
  insert into public.scan_counts (user_id, month, count)
  values (auth.uid(), v_month, 0)
  on conflict (user_id, month) do nothing;

  select count into v_count
  from public.scan_counts
  where user_id = auth.uid() and month = v_month
  for update;

  v_allowed := v_count < p_limit;
  if v_allowed then
    v_count := v_count + 1;
    update public.scan_counts
    set count = v_count, updated_at = now()
    where user_id = auth.uid() and month = v_month;
  end if;

  return jsonb_build_object('allowed', v_allowed, 'count', v_count);
end;
$$;

grant execute on function public.increment_scan_count(int) to authenticated;

create index if not exists idx_scan_counts_user on public.scan_counts(user_id);

-- ── OCR debug logs retention (30 days) ────────────────────────────────
-- Added ahead of possibly extending debug logging beyond tester accounts
-- to real users (see KAN-17) — raw receipt text shouldn't accumulate
-- indefinitely once it's real customers' data, not just test scans.
-- Call manually (`select public.purge_old_ocr_debug_logs();`) or schedule
-- with pg_cron if enabled on the project; not scheduled automatically here
-- since pg_cron availability depends on the Supabase plan.
create or replace function public.purge_old_ocr_debug_logs()
returns void
language sql
security definer
as $$
  delete from public.ocr_debug_logs where created_at < now() - interval '30 days';
$$;

-- ── Per-email auth-email rate limiting ────────────────────────────────
-- Supabase's own rate limit for outgoing auth emails (signup confirmation,
-- password reset, magic links) is project-wide — every user shares one
-- pool (2/hour on the built-in mailer, 30/hour on this project's Brevo
-- custom SMTP by default). One user testing repeatedly, or a burst of
-- real signups, can exhaust that shared pool and block a completely
-- different, genuine user's first attempt — which is indistinguishable
-- from a real outage on the client side. This gives each *email address*
-- its own small quota, checked *before* calling Supabase, so:
--   - a genuine user retrying a few times (typo'd address, spam folder,
--     slow delivery) is essentially never blocked by their own past
--     attempts alone
--   - one address being hammered can't consume another address's budget
--   - the specific, accurate reason ("you've asked for this email too
--     many times") is knowable immediately, client-side, rather than
--     only after Supabase's shared cap happens to already be exhausted
-- Supabase's own project-wide cap still applies underneath this as a
-- second line of defense — this doesn't replace it, it just means that
-- cap should rarely be the thing a genuine user actually hits.
create table if not exists public.auth_email_requests (
  email        text primary key,
  window_start timestamptz not null default now(),
  count        int not null default 0,
  updated_at   timestamptz not null default now()
);

-- No select/insert/update policy for anon or authenticated — this table
-- is never read or written directly by a client, only through the
-- SECURITY DEFINER function below, so RLS being "on with no policies"
-- (the default once enabled) is exactly what's wanted: nobody can read
-- another address's request history or reset their own counter early.
alter table public.auth_email_requests enable row level security;

-- Runs *before* Supabase's own signUp()/resetPasswordForEmail() call, so
-- it must be callable while fully unauthenticated (anon role) — there is
-- no session yet during signup, and a password-reset requester isn't
-- signed in either. `for update` row-locks the one matching email so two
-- concurrent requests for the same address can't both read the
-- pre-increment count and both slip under the limit.
create or replace function public.check_auth_email_rate_limit(
  p_email text,
  p_max_per_window int default 3,
  p_window_minutes int default 15
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_email text := lower(trim(p_email));
  v_window_start timestamptz;
  v_count int;
  v_allowed boolean;
begin
  insert into public.auth_email_requests (email, window_start, count)
  values (v_email, now(), 0)
  on conflict (email) do nothing;

  select window_start, count into v_window_start, v_count
  from public.auth_email_requests
  where email = v_email
  for update;

  -- Window expired — start a fresh one rather than accumulating forever.
  if now() - v_window_start > (p_window_minutes || ' minutes')::interval then
    v_window_start := now();
    v_count := 0;
  end if;

  v_allowed := v_count < p_max_per_window;
  if v_allowed then
    v_count := v_count + 1;
  end if;

  update public.auth_email_requests
  set window_start = v_window_start, count = v_count, updated_at = now()
  where email = v_email;

  return jsonb_build_object(
    'allowed', v_allowed,
    'count', v_count,
    'max', p_max_per_window,
    'window_minutes', p_window_minutes
  );
end;
$$;

grant execute on function public.check_auth_email_rate_limit(text, int, int)
  to anon, authenticated;
