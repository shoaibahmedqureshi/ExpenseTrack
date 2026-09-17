// Resolves a human-typed influencer code (e.g. "SARA20") entered on the
// paywall into what the app needs to redeem it.
//
// iOS and Android diverge here: Android's offerId still gets matched
// against a live entry in the already-fetched Play Billing catalog, so a
// stored discount description would just be redundant with what's already
// on-device. iOS switched to Apple's native Offer Codes — offerId there is
// the real, developer-chosen Apple code string (redeemed via a direct App
// Store URL, not a signed in-app purchase) — and there's no local catalog
// entry for a native code to read a live price from, so discountDescription
// and productId are returned for iOS to display and to know which product
// card to apply the code to.
//
// Deployed with the default Supabase gateway JWT check left ON (unlike
// the two webhook functions) — this is called directly by the app for a
// logged-in user, not by Apple/Google server-to-server, so requiring a
// valid Supabase session is the right gate here. influencer_codes itself
// has no client RLS policy though, so the actual lookup still goes
// through the service-role key internally.
import { createClient } from 'npm:@supabase/supabase-js@2';

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    const { code, platform } = await req.json();

    if (typeof code !== 'string' || code.trim().length === 0) {
      return new Response(JSON.stringify({ error: 'invalid_code' }), { status: 400 });
    }
    if (platform !== 'ios' && platform !== 'android') {
      return new Response(JSON.stringify({ error: 'invalid_platform' }), { status: 400 });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: influencerCode } = await supabase
      .from('influencer_codes')
      .select('platform_offer_id, discount_description, product_id')
      .eq('platform', platform)
      .ilike('code', code.trim())
      .eq('active', true)
      .maybeSingle();

    if (!influencerCode) {
      return new Response(JSON.stringify({ error: 'not_found' }), { status: 404 });
    }

    return new Response(
      JSON.stringify({
        offerId: influencerCode.platform_offer_id,
        discountDescription: influencerCode.discount_description,
        productId: influencerCode.product_id,
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('[resolve-offer-code] error:', err);
    return new Response(JSON.stringify({ error: 'bad_request' }), { status: 400 });
  }
});
