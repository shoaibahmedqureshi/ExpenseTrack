-- ── Human-readable influencer redemption codes ─────────────────────────
-- influencer_codes previously only stored the Apple/Google-side offer
-- identifier (platform_offer_id) used to reconcile webhook notifications.
-- The in-app "enter a code, see the discount" paywall flow needs a
-- separate human-friendly string (e.g. "SARA20") that a user actually
-- types — Apple/Google never see this value, it's purely how the app
-- resolves which offer to apply.

alter table public.influencer_codes
  add column code text;

-- Backfill any pre-existing rows (e.g. staging's placeholder test row)
-- with a derived code so the NOT NULL below can apply cleanly — nothing
-- live depends on these values yet.
update public.influencer_codes
  set code = upper(regexp_replace(platform_offer_id, '[^a-zA-Z0-9]', '', 'g'))
  where code is null;

alter table public.influencer_codes
  alter column code set not null;

-- Not globally unique: an influencer's iOS row and Android row share the
-- same code text, so uniqueness is scoped per platform instead.
alter table public.influencer_codes
  add constraint influencer_codes_platform_code_key unique (platform, code);
