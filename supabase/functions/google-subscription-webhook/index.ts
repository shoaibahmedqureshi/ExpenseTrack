// Google Play Real-time Developer Notifications (RTDN) webhook.
//
// Delivered via a Cloud Pub/Sub push subscription pointed at this
// function's URL. Unlike Apple's notifications, Google's payload only
// carries { purchaseToken, subscriptionId, notificationType } — no offer
// ID or price — so this calls the Play Developer API back to fetch the
// actual purchase details before we know which influencer (if any) to
// attribute it to.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { createRemoteJWKSet, jwtVerify } from 'npm:jose@5';
import { GoogleAuth } from 'npm:google-auth-library@9';

// Pub/Sub push subscriptions configured with "Enable authentication"
// send a Google-signed OIDC token in the Authorization header. Verifying
// it is what proves this request actually came from our Pub/Sub
// subscription and not an arbitrary POST to this public URL.
const GOOGLE_JWKS = createRemoteJWKSet(
  new URL('https://www.googleapis.com/oauth2/v3/certs'),
);

async function verifyPubSubToken(req: Request): Promise<void> {
  const auth = req.headers.get('authorization');
  if (!auth?.startsWith('Bearer ')) {
    throw new Error('Missing bearer token');
  }
  const token = auth.slice('Bearer '.length);
  const expectedAudience = Deno.env.get('PUBSUB_AUDIENCE');
  const expectedServiceAccount = Deno.env.get('PUBSUB_PUSH_SERVICE_ACCOUNT');

  const { payload } = await jwtVerify(token, GOOGLE_JWKS, {
    audience: expectedAudience || undefined,
  });

  if (expectedServiceAccount && payload.email !== expectedServiceAccount) {
    throw new Error('Unexpected service account in token');
  }
}

let cachedAuthClient: GoogleAuth | null = null;

function getGoogleAuth(): GoogleAuth {
  if (cachedAuthClient) return cachedAuthClient;
  const credentialsJson = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON');
  if (!credentialsJson) {
    throw new Error('GOOGLE_SERVICE_ACCOUNT_JSON not configured');
  }
  cachedAuthClient = new GoogleAuth({
    credentials: JSON.parse(credentialsJson),
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  return cachedAuthClient;
}

async function fetchSubscriptionPurchase(packageName: string, purchaseToken: string) {
  const auth = getGoogleAuth();
  const client = await auth.getClient();
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${packageName}/purchases/subscriptionsv2/tokens/${purchaseToken}`;
  const res = await client.request({ url });
  return res.data as Record<string, unknown>;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    await verifyPubSubToken(req);

    const body = await req.json();
    // Pub/Sub push envelope: { message: { data: "<base64 JSON>", ... } }
    const dataB64 = body?.message?.data;
    if (!dataB64) {
      return new Response('OK (no message data)', { status: 200 });
    }
    const decoded = JSON.parse(atob(dataB64));
    const subNotification = decoded.subscriptionNotification;
    if (!subNotification) {
      // Test notifications and other message types carry no subscription
      // event — nothing to attribute.
      return new Response('OK (not a subscription event)', { status: 200 });
    }

    const packageName = decoded.packageName as string;
    const purchaseToken = subNotification.purchaseToken as string;
    const productId = subNotification.subscriptionId as string;
    const notificationType = String(subNotification.notificationType);

    const purchase = await fetchSubscriptionPurchase(packageName, purchaseToken);

    // Defensive extraction — Play's exact response shape for a given
    // line item can vary, and the full raw response is stored below
    // regardless, so an unexpected shape here loses attribution/payout
    // for this event but never loses the underlying data.
    const lineItems = (purchase.lineItems as Array<Record<string, unknown>>) ?? [];
    const lineItem = lineItems.find((li) => li.productId === productId) ?? lineItems[0];
    const offerId = (lineItem?.offerDetails as Record<string, unknown> | undefined)?.offerId as
      | string
      | undefined;

    if (!offerId) {
      return new Response('OK (no offer)', { status: 200 });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: influencerCode } = await supabase
      .from('influencer_codes')
      .select('id, revenue_share_percent')
      .eq('platform', 'android')
      .eq('platform_offer_id', offerId)
      .eq('active', true)
      .maybeSingle();

    if (!influencerCode) {
      return new Response('OK (untracked offer)', { status: 200 });
    }

    // Play's subscriptionsv2 resource doesn't carry a simple "amount
    // paid" field the way Apple's transaction info does — record the
    // purchase with the raw response attached so the actual price can
    // be filled in from Play Console's own financial reports at payout
    // time, rather than guessing a field path here.
    await supabase.from('subscription_referrals').upsert(
      {
        influencer_code_id: influencerCode.id,
        platform: 'android',
        product_id: productId,
        transaction_id: purchaseToken,
        event_type: notificationType,
        raw_notification: purchase,
      },
      { onConflict: 'platform,transaction_id' },
    );

    return new Response('OK', { status: 200 });
  } catch (err) {
    console.error('[google-subscription-webhook] error:', err);
    return new Response('Verification failed', { status: 400 });
  }
});
