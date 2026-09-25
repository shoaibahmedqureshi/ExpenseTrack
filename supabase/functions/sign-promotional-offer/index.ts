// Signs an Apple Promotional Offer redemption, generated fresh for each
// purchase attempt — never cached, since the nonce/timestamp pair is only
// valid for the one StoreKit purchase call the app makes immediately
// after receiving this response.
//
// Re-validates the code server-side rather than trusting whatever offer
// id the client believes resolve-offer-code returned earlier, since
// forging a signed offer would mean forging a real discount at purchase
// time, not just a display glitch.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { PromotionalOfferSignatureCreator } from 'npm:@apple/app-store-server-library@1';

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'unauthenticated' }), { status: 401 });
    }

    const { code, productId } = await req.json();
    if (typeof code !== 'string' || code.trim().length === 0) {
      return new Response(JSON.stringify({ error: 'invalid_code' }), { status: 400 });
    }
    if (typeof productId !== 'string' || productId.trim().length === 0) {
      return new Response(JSON.stringify({ error: 'invalid_product_id' }), { status: 400 });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;

    // Identifies the calling user from their own session token — this
    // becomes the signature's applicationUsername, which also flows back
    // to us as appAccountToken on the resulting Apple transaction, so
    // apple-subscription-webhook can finally attribute a purchase to a
    // specific Supabase user instead of leaving user_id null.
    const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'unauthenticated' }), { status: 401 });
    }

    const supabase = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { data: influencerCode } = await supabase
      .from('influencer_codes')
      .select('platform_offer_id')
      .eq('platform', 'ios')
      .ilike('code', code.trim())
      .eq('active', true)
      .maybeSingle();

    if (!influencerCode) {
      return new Response(JSON.stringify({ error: 'not_found' }), { status: 404 });
    }

    const encodedKey = Deno.env.get('APPLE_SUBSCRIPTION_KEY');
    const keyId = Deno.env.get('APPLE_SUBSCRIPTION_KEY_ID');
    if (!encodedKey || !keyId) {
      // Not yet configured (Shoaib generates this key in App Store
      // Connect) — fail clearly rather than let the library throw an
      // opaque error deeper in.
      console.error('[sign-promotional-offer] APPLE_SUBSCRIPTION_KEY(_ID) not configured');
      return new Response(JSON.stringify({ error: 'not_configured' }), { status: 500 });
    }
    const bundleId = Deno.env.get('APPLE_BUNDLE_ID') ?? 'com.codebloom.outlay';

    const signatureCreator = new PromotionalOfferSignatureCreator(encodedKey, keyId, bundleId);
    const nonce = crypto.randomUUID();
    const timestamp = Date.now();
    const applicationUsername = user.id;

    const signature = signatureCreator.createSignature(
      productId,
      influencerCode.platform_offer_id,
      applicationUsername,
      nonce,
      timestamp,
    );

    return new Response(
      JSON.stringify({
        offerId: influencerCode.platform_offer_id,
        keyId,
        nonce,
        signature,
        timestamp,
        applicationUsername,
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('[sign-promotional-offer] error:', err);
    return new Response(JSON.stringify({ error: 'bad_request' }), { status: 400 });
  }
});
