-- ── Native Offer Code redemption support ────────────────────────────────
-- Apple Promotional Offers (what platform_offer_id/signing were originally
-- built for) turn out to be ineligible for brand-new customers — Apple's
-- own server rejects the purchase outright for anyone who's never
-- subscribed before, which is most of an influencer's actual audience.
-- Switched to Apple's native Offer Codes instead: platform_offer_id is now
-- the real, developer-chosen Apple custom code string itself (e.g.
-- "SARA20" maps to Apple code "SARA20" directly), redeemed via a direct
-- App Store URL rather than a signed in-app purchase.
--
-- Two consequences of dropping the live StoreKit lookup this replaces:
-- there's no local catalog entry to read a live discounted price from
-- anymore, so we store a human-written description to display instead;
-- and the code no longer implicitly targets "whichever product has a
-- matching offer" (there's no catalog matching at all now), so which
-- product it applies to has to be explicit.

alter table public.influencer_codes
  add column discount_description text;

alter table public.influencer_codes
  add column product_id text;

comment on column public.influencer_codes.discount_description is
  'Human-written summary shown in the app before redemption (e.g. "$14.99 for your first year") — iOS only, since Android still reads a live price from the Play Billing catalog.';

comment on column public.influencer_codes.product_id is
  'Which subscription product (e.g. expense_tracker_pro_annual) this code''s offer applies to — no longer inferrable from a live StoreKit catalog match now that iOS redeems via a native Offer Code rather than a signed Promotional Offer.';
