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
import { computeOrderPayout, parseVoidedPurchase, type PlayOrder } from '../_shared/play_order.ts';

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

// The subscription resource carries no amount paid; the Orders API does (needs the service
// account's "View financial data" permission, which it already has).
async function fetchOrder(packageName: string, orderId: string): Promise<PlayOrder> {
  const auth = getGoogleAuth();
  const client = await auth.getClient();
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${packageName}/orders/${encodeURIComponent(orderId)}`;
  const res = await client.request({ url });
  return res.data as PlayOrder;
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

    // Refunds and chargebacks arrive as their own message type. Void the creator's purchase so it
    // drops out of what they are owed (or raises an alert if it was already paid).
    const voided = parseVoidedPurchase(decoded);
    if (voided) {
      const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
      const { data: outcome, error: voidError } = await admin.rpc('system_void_referral', {
        p_platform: 'android',
        p_transaction_id: voided.purchaseToken,
        p_reason: 'Refunded in Google Play',
        p_order_id: voided.orderId ?? null,
      });
      if (voidError) throw voidError;
      console.log('[google-subscription-webhook] voided purchase:', outcome);
      return new Response(`OK (void: ${outcome})`, { status: 200 });
    }

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

    // Once a purchase has its amount it is never rewritten: Play re-sends notifications for the same
    // purchase token (renewals, state changes) and a later, full-price order must not replace the
    // discounted first one that the creator is paid on.
    const { data: existing } = await supabase
      .from('subscription_referrals')
      .select('id, payout_amount')
      .eq('platform', 'android')
      .eq('transaction_id', purchaseToken)
      .maybeSingle();
    if (existing && existing.payout_amount !== null) {
      return new Response('OK (already recorded)', { status: 200 });
    }

    // The subscription resource has no amount; read it from the order. A failure here must not lose the
    // attribution, so the row is still written without an amount (the admin portal flags those) and a
    // later notification for the same token will try again.
    let amounts: { purchase_amount?: number; payout_amount?: number; currency?: string } = {};
    const orderId = purchase.latestOrderId as string | undefined;
    if (orderId) {
      try {
        const order = await fetchOrder(packageName, orderId);
        const result = computeOrderPayout(order, offerId, Number(influencerCode.revenue_share_percent));
        if (result.ok) {
          amounts = {
            purchase_amount: result.purchaseAmount,
            payout_amount: result.payoutAmount,
            currency: result.currency,
          };
        } else {
          console.warn('[google-subscription-webhook] no payout for order:', orderId, result.reason);
        }
      } catch (orderErr) {
        console.error('[google-subscription-webhook] order lookup failed:', orderErr);
      }
    } else {
      console.warn('[google-subscription-webhook] purchase has no latestOrderId');
    }

    await supabase.from('subscription_referrals').upsert(
      {
        influencer_code_id: influencerCode.id,
        platform: 'android',
        product_id: productId,
        transaction_id: purchaseToken,
        event_type: notificationType,
        raw_notification: purchase,
        ...amounts,
      },
      { onConflict: 'platform,transaction_id' },
    );

    return new Response('OK', { status: 200 });
  } catch (err) {
    console.error('[google-subscription-webhook] error:', err);
    return new Response('Verification failed', { status: 400 });
  }
});
