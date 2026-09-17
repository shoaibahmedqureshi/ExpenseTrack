-- ── Lifetime scan count + one-time review prompt ──────────────────────
-- Separate from scan_counts (which is monthly and resets) — this is an
-- all-time total used only to trigger the native in-app review prompt
-- once, after the user's 3rd kept scan. Server-side for the same reason
-- as the monthly limit: a local-only counter is inconsistent across
-- devices (could prompt twice) and resets on reinstall.
alter table public.profiles
  add column if not exists lifetime_scan_count int not null default 0,
  add column if not exists review_prompted boolean not null default false;

-- Atomically increments the lifetime count and reports whether *this*
-- call is the one that just crossed the threshold — i.e. whether the
-- client should fire the native review prompt now. review_prompted is
-- flipped in the same statement so concurrent calls from two devices
-- can't both get "true" back.
create or replace function public.increment_lifetime_scan_count(p_threshold int)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_count           int;
  v_already_prompted boolean;
  v_should_prompt   boolean := false;
begin
  update public.profiles
  set lifetime_scan_count = lifetime_scan_count + 1
  where id = auth.uid()
  returning lifetime_scan_count, review_prompted
  into v_count, v_already_prompted;

  if v_count >= p_threshold and not v_already_prompted then
    update public.profiles
    set review_prompted = true
    where id = auth.uid();
    v_should_prompt := true;
  end if;

  return jsonb_build_object('count', v_count, 'shouldPrompt', v_should_prompt);
end;
$$;

grant execute on function public.increment_lifetime_scan_count(int) to authenticated;
