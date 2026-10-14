// Turns what a store says about a subscription into the one fact the server needs: which plan, and until when.
// Pure functions only, so they can be tested without Deno or network access.

export type Plan = 'pro_monthly' | 'pro_annual' | 'max_monthly' | 'max_annual';

const PRODUCT_PLAN: Record<string, Plan> = {
  expense_tracker_pro_monthly: 'pro_monthly',
  expense_tracker_pro_annual: 'pro_annual',
  expense_tracker_max_monthly: 'max_monthly',
  expense_tracker_max_annual: 'max_annual',
};

export function planFromProductId(productId: unknown): Plan | null {
  return typeof productId === 'string' ? (PRODUCT_PLAN[productId] ?? null) : null;
}

export interface Entitlement {
  plan: Plan;
  productId: string;
  originalTransactionId: string;
  expiresAt: Date;
}

const toDate = (ms: unknown): Date | null =>
  typeof ms === 'number' && Number.isFinite(ms) ? new Date(ms) : null;

/**
 * From a verified Apple transaction (signedTransactionInfo). A revoked or refunded transaction ends access at the
 * revocation time. `renewalInfo` is the verified signedRenewalInfo, when present: during billing retry Apple keeps
 * the subscriber entitled until gracePeriodExpiresDate even though expiresDate has passed.
 */
export function entitlementFromAppleTransaction(
  tx: Record<string, unknown>,
  renewalInfo?: Record<string, unknown> | null,
): Entitlement | null {
  const plan = planFromProductId(tx.productId);
  const original = tx.originalTransactionId;
  if (!plan || original === undefined || original === null) return null;

  const revoked = toDate(tx.revocationDate);
  let expires = toDate(tx.expiresDate);
  if (!expires) return null;
  if (revoked) {
    expires = revoked;
  } else {
    const grace = toDate(renewalInfo?.gracePeriodExpiresDate);
    if (grace && grace > expires) expires = grace;
  }
  return {
    plan,
    productId: String(tx.productId),
    originalTransactionId: String(original),
    expiresAt: expires,
  };
}

const NO_ACCESS_STATES = new Set([
  'SUBSCRIPTION_STATE_EXPIRED',
  'SUBSCRIPTION_STATE_ON_HOLD',
  'SUBSCRIPTION_STATE_PAUSED',
  'SUBSCRIPTION_STATE_PENDING',
]);

/**
 * From a Play subscriptionsv2 purchase. Cancelled-but-not-yet-expired subscriptions still have access until
 * expiryTime. Expired, on-hold, paused and pending ones have none, whatever expiryTime says.
 */
export function entitlementFromGooglePurchase(
  purchase: Record<string, unknown>,
  productId: string,
  purchaseToken: string,
  now: Date = new Date(),
): Entitlement | null {
  const plan = planFromProductId(productId);
  if (!plan) return null;
  const items = (purchase.lineItems as Array<Record<string, unknown>> | undefined) ?? [];
  const item = items.find((li) => li.productId === productId) ?? items[0];
  const expiry = typeof item?.expiryTime === 'string' ? new Date(item.expiryTime) : null;
  if (!expiry || Number.isNaN(expiry.getTime())) return null;

  const state = String(purchase.subscriptionState ?? '');
  const expiresAt = NO_ACCESS_STATES.has(state) && expiry > now ? now : expiry;
  return { plan, productId, originalTransactionId: purchaseToken, expiresAt };
}

export const isMaxPlan = (plan: string): boolean => plan.startsWith('max_');
