// Turns a Google Play Orders API order (orders.get) into the purchase and payout amounts we record.
// Pure functions only, so they can be tested without calling Google.

export interface Money {
  currencyCode?: string;
  units?: string | number;
  nanos?: number;
}

export interface PlayOrder {
  state?: string;
  total?: Money;
  tax?: Money;
  lineItems?: Array<{
    subscriptionDetails?: {
      offerId?: string;
      offerPhaseDetails?: Record<string, unknown>;
    };
  }>;
}

export type OrderPayout =
  | { ok: true; purchaseAmount: number; payoutAmount: number; currency: string }
  | { ok: false; reason: string };

export function moneyToNumber(m: Money | undefined): number | null {
  if (!m) return null;
  const units = Number(m.units ?? 0);
  const nanos = Number(m.nanos ?? 0);
  if (!Number.isFinite(units) || !Number.isFinite(nanos)) return null;
  return units + nanos / 1e9;
}

/**
 * The amount we pay a creator on is what the buyer paid for this order excluding tax
 * (`total` is the final amount including tax), times the creator's share.
 *
 * Only the order that carries the influencer's own offer in an introductory or free-trial phase counts, so a
 * later full-price renewal can never be mistaken for the discounted first purchase.
 */
export function computeOrderPayout(order: PlayOrder, offerId: string, sharePercent: number): OrderPayout {
  if (order.state !== 'PROCESSED') return { ok: false, reason: `order state is ${order.state ?? 'unknown'}` };

  const item = (order.lineItems ?? []).find((li) => li.subscriptionDetails?.offerId === offerId);
  if (!item) return { ok: false, reason: 'order does not carry the influencer offer' };
  const phase = item.subscriptionDetails?.offerPhaseDetails ?? {};
  if (!('introductoryPriceDetails' in phase) && !('freeTrialDetails' in phase)) {
    return { ok: false, reason: 'order is not in the offer\'s discounted phase' };
  }

  const total = moneyToNumber(order.total);
  const currency = order.total?.currencyCode;
  if (total === null || !currency) return { ok: false, reason: 'order has no total' };
  const tax = moneyToNumber(order.tax) ?? 0;

  const net = Math.max(0, Math.round((total - tax) * 100) / 100);
  if (!Number.isFinite(sharePercent) || sharePercent < 0) return { ok: false, reason: 'invalid revenue share' };
  const payout = Math.round(net * (sharePercent / 100) * 100) / 100;
  return { ok: true, purchaseAmount: net, payoutAmount: payout, currency };
}

export interface VoidedPurchase {
  purchaseToken: string;
  orderId?: string;
}

/**
 * Play sends refunds and chargebacks as a `voidedPurchaseNotification` on the same topic.
 * Only subscription purchases (productType 1) matter here.
 */
export function parseVoidedPurchase(decoded: Record<string, unknown> | undefined | null): VoidedPurchase | null {
  const v = decoded?.voidedPurchaseNotification as Record<string, unknown> | undefined;
  if (!v || typeof v.purchaseToken !== 'string' || !v.purchaseToken) return null;
  if (Number(v.productType) !== 1) return null;
  return { purchaseToken: v.purchaseToken, orderId: typeof v.orderId === 'string' && v.orderId ? v.orderId : undefined };
}
