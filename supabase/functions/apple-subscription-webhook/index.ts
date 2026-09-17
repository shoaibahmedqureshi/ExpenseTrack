// Apple App Store Server Notifications V2 webhook.
//
// Registered in App Store Connect → your app → General → App Information
// → App Store Server Notifications (separate URLs for Sandbox and
// Production — this same function handles both; Apple's own payload
// tells us which environment it came from).
//
// Verifies the signed payload using a hand-rolled verifier (see
// _shared/apple_jws_verify.ts) rather than Apple's official
// @apple/app-store-server-library: that library's SignedDataVerifier
// depends on Node's native X509Certificate.prototype.verify(), which
// Deno's Node-compatibility layer does not implement — confirmed by
// directly testing it against this exact runtime, where it throws
// `Error [ERR_NOT_IMPLEMENTED]`. The replacement was verified against real
// Apple-signed production and sandbox payloads, including confirming it
// correctly rejects a tampered payload and a wrong-bundle-ID expectation,
// before it replaced the official library here.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { verifyAndDecodeAppleJWS } from '../_shared/apple_jws_verify.ts';

const APPLE_BUNDLE_ID = Deno.env.get('APPLE_BUNDLE_ID') ?? 'com.codebloom.outlay';
// Outlay's numeric Apple App ID — only present on notification payloads
// once the environment is Production (Sandbox payloads omit it entirely).
const APPLE_APP_ID = 6790199113;

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    const { signedPayload } = await req.json();
    if (!signedPayload) {
      return new Response('Missing signedPayload', { status: 400 });
    }

    // Throws if the signature or certificate chain doesn't check out —
    // this is the step that actually authenticates the notification as
    // genuinely from Apple rather than an arbitrary POST to this URL.
    const payload = await verifyAndDecodeAppleJWS(signedPayload);
    const data = payload.data as
      | { bundleId?: string; appAppleId?: number; environment?: string; signedTransactionInfo?: string }
      | undefined;

    if (data?.bundleId && data.bundleId !== APPLE_BUNDLE_ID) {
      throw new Error(`Bundle ID mismatch: ${data.bundleId}`);
    }
    // SignedDataVerifier used to enforce this via its environment
    // constructor argument — replicated explicitly here now, matching the
    // same production/sandbox split the two registered notification URLs
    // already give us (see APPLE_ENVIRONMENT).
    const expectedEnvironment =
      Deno.env.get('APPLE_ENVIRONMENT') === 'production' ? 'Production' : 'Sandbox';
    if (data?.environment && data.environment !== expectedEnvironment) {
      throw new Error(
        `Environment mismatch: expected ${expectedEnvironment}, got ${data.environment}`,
      );
    }
    if (data?.appAppleId && data.appAppleId !== APPLE_APP_ID) {
      throw new Error(`App Apple ID mismatch: ${data.appAppleId}`);
    }

    const notificationType = payload.notificationType as string;
    const transactionInfo = data?.signedTransactionInfo
      ? await verifyAndDecodeAppleJWS(data.signedTransactionInfo)
      : null;

    if (!transactionInfo) {
      // Notification types we don't care about (e.g. CONSENT_REVOKED,
      // TEST) carry no transaction — nothing to attribute, ack and exit.
      return new Response('OK (no transaction)', { status: 200 });
    }

    const offerIdentifier = transactionInfo.offerIdentifier as string | undefined;
    if (!offerIdentifier) {
      // A normal subscription with no offer code attached — not an
      // influencer-attributed purchase, nothing to record.
      return new Response('OK (no offer)', { status: 200 });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: influencerCode } = await supabase
      .from('influencer_codes')
      .select('id, revenue_share_percent')
      .eq('platform', 'ios')
      .eq('platform_offer_id', offerIdentifier)
      .eq('active', true)
      .maybeSingle();

    if (!influencerCode) {
      // Offer code exists on Apple's side but isn't one we're tracking
      // for revenue share (e.g. a plain promotional discount) — ack and
      // skip rather than erroring, so Apple doesn't keep retrying.
      return new Response('OK (untracked offer)', { status: 200 });
    }

    const priceMicros = (transactionInfo.price as number) ?? 0; // Apple sends price in milliunits
    const purchaseAmount = priceMicros / 1000;
    const payoutAmount =
      Math.round(purchaseAmount * (Number(influencerCode.revenue_share_percent) / 100) * 100) /
      100;

    const referralRow = {
      influencer_code_id: influencerCode.id,
      // sign-promotional-offer sets applicationUsername to the buyer's
      // Supabase user id, which Apple echoes back here on the resulting
      // transaction — the only way to attribute a purchase to a specific
      // account, since nothing else in this payload identifies one. Today's
      // redemption flow never actually sets this (see redeemOffer in the
      // app), so this is normally already null — the fallback below exists
      // for if that ever changes and Apple echoes back a stale/invalid
      // token that doesn't match a real profiles row.
      user_id: (transactionInfo.appAccountToken as string | undefined) ?? null,
      platform: 'ios',
      product_id: transactionInfo.productId,
      transaction_id: transactionInfo.transactionId,
      event_type: notificationType,
      purchase_amount: purchaseAmount,
      currency: transactionInfo.currency ?? null,
      payout_amount: payoutAmount,
      raw_notification: payload,
    };

    const { error: upsertError } = await supabase
      .from('subscription_referrals')
      .upsert(referralRow, { onConflict: 'platform,transaction_id' });

    if (upsertError) {
      // A bad appAccountToken (references no real profiles row) must not
      // cost us the whole payout record — losing the influencer/purchase
      // attribution over a foreign key we can retry without is worse than
      // just dropping the user link. Any other failure still propagates.
      if (upsertError.code === '23503' && referralRow.user_id !== null) {
        const { error: retryError } = await supabase
          .from('subscription_referrals')
          .upsert({ ...referralRow, user_id: null }, { onConflict: 'platform,transaction_id' });
        if (retryError) throw retryError;
      } else {
        throw upsertError;
      }
    }

    return new Response('OK', { status: 200 });
  } catch (err) {
    console.error('[apple-subscription-webhook] error:', err);
    // 400, not 500 — a verification failure means a malformed/untrusted
    // payload, not a transient server problem, so Apple shouldn't retry
    // it as if this were an outage.
    return new Response('Verification failed', { status: 400 });
  }
});
