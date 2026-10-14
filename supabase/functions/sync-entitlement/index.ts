// Records which paid plan the signed-in user holds, verified against the store, so the server can tie a family to
// its admin's MAX. The app sends only proof, never a plan:
//   Apple:  { store: 'apple',  signedTransaction }   the StoreKit 2 JWS, checked against Apple's certificate chain
//   Google: { store: 'google', purchaseToken, productId }   checked by asking the Play Developer API
// Deployed with the gateway JWT check on: only a signed-in user can call it, and the entitlement is attached to
// that user and no one else. Later renewals, expiries and refunds arrive through the two store webhooks.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { GoogleAuth } from 'npm:google-auth-library@9';
import { verifyAndDecodeAppleJWS } from '../_shared/apple_jws_verify.ts';
import {
  entitlementFromAppleTransaction,
  entitlementFromGooglePurchase,
  type Entitlement,
} from '../_shared/entitlement.ts';
import { linkEntitlement } from '../_shared/entitlement_store.ts';

const APPLE_BUNDLE_ID = Deno.env.get('APPLE_BUNDLE_ID') ?? 'com.codebloom.outlay';
const ANDROID_PACKAGE = Deno.env.get('ANDROID_PACKAGE_NAME') ?? 'com.outlay.app';

const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

async function fetchPlayPurchase(purchaseToken: string): Promise<Record<string, unknown>> {
  const credentialsJson = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON');
  if (!credentialsJson) throw new Error('GOOGLE_SERVICE_ACCOUNT_JSON not configured');
  const auth = new GoogleAuth({
    credentials: JSON.parse(credentialsJson),
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const client = await auth.getClient();
  const res = await client.request({
    url:
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${ANDROID_PACKAGE}` +
      `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
  });
  return res.data as Record<string, unknown>;
}

async function entitlementFromRequest(body: Record<string, unknown>): Promise<Entitlement | null> {
  if (body.store === 'apple') {
    if (typeof body.signedTransaction !== 'string') return null;
    // Throws unless the signature and certificate chain check out: this is what makes the claim trustworthy.
    const tx = await verifyAndDecodeAppleJWS(body.signedTransaction);
    if (tx.bundleId !== APPLE_BUNDLE_ID) throw new Error(`Bundle ID mismatch: ${tx.bundleId}`);
    // Both Production and Sandbox are accepted: a real customer's production build cannot produce a Sandbox
    // transaction, and App Review / TestFlight testers legitimately do.
    return entitlementFromAppleTransaction(tx);
  }
  if (body.store === 'google') {
    if (typeof body.purchaseToken !== 'string' || typeof body.productId !== 'string') return null;
    const purchase = await fetchPlayPurchase(body.purchaseToken);
    return entitlementFromGooglePurchase(purchase, body.productId, body.purchaseToken);
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  try {
    const url = Deno.env.get('SUPABASE_URL') ?? '';
    const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY') ?? '', {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) return reply({ error: 'sign_in_required' }, 401);

    const body = await req.json().catch(() => ({}));
    let entitlement: Entitlement | null;
    try {
      entitlement = await entitlementFromRequest(body);
    } catch (e) {
      console.error('[sync-entitlement] verification failed:', e);
      return reply({ error: 'verification_failed' }, 400);
    }
    if (!entitlement) return reply({ error: 'no_valid_entitlement' }, 400);

    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
    const outcome = await linkEntitlement(admin, userData.user.id, body.store, entitlement);
    if (outcome === 'claimed') return reply({ error: 'already_linked_to_another_account' }, 409);

    return reply({ plan: entitlement.plan, expiresAt: entitlement.expiresAt.toISOString() });
  } catch (e) {
    console.error('[sync-entitlement] error:', e);
    return reply({ error: 'server_error' }, 500);
  }
});
