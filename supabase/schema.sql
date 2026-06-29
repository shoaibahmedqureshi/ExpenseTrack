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

-- Profiles: users can read and update only their own row
create policy "profiles_select" on public.profiles for select using (auth.uid() = id);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

-- Categories: full CRUD on own rows
create policy "categories_all" on public.categories for all using (auth.uid() = user_id);

-- Expenses: full CRUD on own rows
create policy "expenses_all" on public.expenses for all using (auth.uid() = user_id);

-- Budgets: full CRUD on own rows
create policy "budgets_all" on public.budgets for all using (auth.uid() = user_id);

-- ── Indexes ──────────────────────────────────────────────────
create index if not exists idx_expenses_user   on public.expenses(user_id);
create index if not exists idx_expenses_date   on public.expenses(date desc);
create index if not exists idx_categories_user on public.categories(user_id);
create index if not exists idx_budgets_user    on public.budgets(user_id);
create index if not exists idx_budgets_month   on public.budgets(month desc);
