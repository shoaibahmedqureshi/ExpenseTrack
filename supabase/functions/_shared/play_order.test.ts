import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeOrderPayout, moneyToNumber, parseVoidedPurchase } from './play_order.ts';

const intro = (total: any, tax: any, state = 'PROCESSED', phase: any = { introductoryPriceDetails: {} }, offerId = 'sara20') => ({
  state, total, tax, lineItems: [{ subscriptionDetails: { offerId, offerPhaseDetails: phase } }],
});

test('money parsing', () => {
  assert.equal(moneyToNumber({ currencyCode: 'USD', units: '14', nanos: 990000000 }), 14.99);
  assert.equal(moneyToNumber({ currencyCode: 'USD' }), 0);
  assert.equal(moneyToNumber(undefined), null);
});
test('20% of the tax-exclusive discounted price', () => {
  const r = computeOrderPayout(intro({ currencyCode: 'USD', units: '11', nanos: 240000000 }, { currencyCode: 'USD', units: '0', nanos: 0 }), 'sara20', 20);
  assert.deepEqual(r, { ok: true, purchaseAmount: 11.24, payoutAmount: 2.25, currency: 'USD' });
});
test('tax is excluded', () => {
  const r = computeOrderPayout(intro({ currencyCode: 'PKR', units: '2360' }, { currencyCode: 'PKR', units: '360' }), 'sara20', 20);
  assert.deepEqual(r, { ok: true, purchaseAmount: 2000, payoutAmount: 400, currency: 'PKR' });
});
test('missing tax counts as zero', () => {
  const r = computeOrderPayout(intro({ currencyCode: 'USD', units: '10' }, undefined), 'sara20', 10);
  assert.deepEqual(r, { ok: true, purchaseAmount: 10, payoutAmount: 1, currency: 'USD' });
});
test('free trial pays nothing but is recorded', () => {
  const r = computeOrderPayout(intro({ currencyCode: 'USD', units: '0' }, undefined, 'PROCESSED', { freeTrialDetails: {} }), 'sara20', 20);
  assert.deepEqual(r, { ok: true, purchaseAmount: 0, payoutAmount: 0, currency: 'USD' });
});
test('a full-price renewal is not counted', () => {
  const r = computeOrderPayout(intro({ currencyCode: 'USD', units: '14', nanos: 990000000 }, undefined, 'PROCESSED', { baseDetails: {} }), 'sara20', 20);
  assert.equal(r.ok, false);
});
test('an order for a different offer is not counted', () => {
  assert.equal(computeOrderPayout(intro({ currencyCode: 'USD', units: '5' }, undefined, 'PROCESSED', { introductoryPriceDetails: {} }, 'other'), 'sara20', 20).ok, false);
});
test('pending, refunded and canceled orders are not counted', () => {
  for (const s of ['PENDING', 'REFUNDED', 'CANCELED', 'PENDING_REFUND', '']) {
    assert.equal(computeOrderPayout(intro({ currencyCode: 'USD', units: '5' }, undefined, s as any), 'sara20', 20).ok, false, String(s));
  }
});
test('bad inputs are rejected', () => {
  assert.equal(computeOrderPayout(intro({ units: '5' }, undefined), 'sara20', 20).ok, false);
  assert.equal(computeOrderPayout(intro({ currencyCode: 'USD', units: '5' }, undefined), 'sara20', NaN).ok, false);
  assert.equal(computeOrderPayout({ state: 'PROCESSED', lineItems: [] }, 'sara20', 20).ok, false);
});
test('tax larger than total never goes negative', () => {
  const r = computeOrderPayout(intro({ currencyCode: 'USD', units: '1' }, { currencyCode: 'USD', units: '2' }), 'sara20', 20);
  assert.deepEqual(r, { ok: true, purchaseAmount: 0, payoutAmount: 0, currency: 'USD' });
});

test('voided subscription purchase is parsed', () => {
  assert.deepEqual(parseVoidedPurchase({ voidedPurchaseNotification: { purchaseToken: 'tok', orderId: 'GPA.1', productType: 1, refundType: 1 } }), { purchaseToken: 'tok', orderId: 'GPA.1' });
  assert.deepEqual(parseVoidedPurchase({ voidedPurchaseNotification: { purchaseToken: 'tok', productType: 1 } }), { purchaseToken: 'tok', orderId: undefined });
});
test('one-time products and malformed messages are ignored', () => {
  assert.equal(parseVoidedPurchase({ voidedPurchaseNotification: { purchaseToken: 'tok', productType: 2 } }), null);
  assert.equal(parseVoidedPurchase({ voidedPurchaseNotification: { productType: 1 } }), null);
  assert.equal(parseVoidedPurchase({ subscriptionNotification: {} }), null);
  assert.equal(parseVoidedPurchase(null), null);
});
