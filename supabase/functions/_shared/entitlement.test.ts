import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  entitlementFromAppleTransaction,
  entitlementFromGooglePurchase,
  isMaxPlan,
  planFromProductId,
} from './entitlement.ts';

const DAY = 86_400_000;
const now = new Date('2026-11-01T00:00:00Z');

test('maps the four product ids and rejects unknown ones', () => {
  assert.equal(planFromProductId('expense_tracker_max_annual'), 'max_annual');
  assert.equal(planFromProductId('expense_tracker_pro_monthly'), 'pro_monthly');
  assert.equal(planFromProductId('something_else'), null);
  assert.equal(planFromProductId(undefined), null);
  assert.equal(isMaxPlan('max_monthly'), true);
  assert.equal(isMaxPlan('pro_annual'), false);
});

test('apple: plan and expiry come from the transaction', () => {
  const e = entitlementFromAppleTransaction({
    productId: 'expense_tracker_max_monthly',
    originalTransactionId: 12345,
    expiresDate: now.getTime() + 30 * DAY,
  });
  assert.equal(e?.plan, 'max_monthly');
  assert.equal(e?.originalTransactionId, '12345');
  assert.equal(e?.expiresAt.getTime(), now.getTime() + 30 * DAY);
});

test('apple: a refund or revoke ends access at the revocation time', () => {
  const e = entitlementFromAppleTransaction({
    productId: 'expense_tracker_max_annual',
    originalTransactionId: '1',
    expiresDate: now.getTime() + 300 * DAY,
    revocationDate: now.getTime() - DAY,
  });
  assert.equal(e?.expiresAt.getTime(), now.getTime() - DAY);
});

test('apple: billing grace keeps access past the expiry date', () => {
  const e = entitlementFromAppleTransaction(
    { productId: 'expense_tracker_max_monthly', originalTransactionId: '1', expiresDate: now.getTime() - DAY },
    { gracePeriodExpiresDate: now.getTime() + 5 * DAY },
  );
  assert.equal(e?.expiresAt.getTime(), now.getTime() + 5 * DAY);
});

test('apple: a grace date earlier than expiry changes nothing', () => {
  const e = entitlementFromAppleTransaction(
    { productId: 'expense_tracker_max_monthly', originalTransactionId: '1', expiresDate: now.getTime() + DAY },
    { gracePeriodExpiresDate: now.getTime() - DAY },
  );
  assert.equal(e?.expiresAt.getTime(), now.getTime() + DAY);
});

test('apple: unknown product, missing id or missing expiry gives nothing', () => {
  assert.equal(entitlementFromAppleTransaction({ productId: 'x', originalTransactionId: '1', expiresDate: 1 }), null);
  assert.equal(entitlementFromAppleTransaction({ productId: 'expense_tracker_max_monthly', expiresDate: 1 }), null);
  assert.equal(entitlementFromAppleTransaction({ productId: 'expense_tracker_max_monthly', originalTransactionId: '1' }), null);
});

const play = (state: string, expiry: Date, productId = 'expense_tracker_max_monthly') => ({
  subscriptionState: state,
  lineItems: [{ productId, expiryTime: expiry.toISOString() }],
});

test('google: an active subscription is entitled until its expiry', () => {
  const exp = new Date(now.getTime() + 20 * DAY);
  const e = entitlementFromGooglePurchase(play('SUBSCRIPTION_STATE_ACTIVE', exp), 'expense_tracker_max_monthly', 'tok', now);
  assert.equal(e?.plan, 'max_monthly');
  assert.equal(e?.originalTransactionId, 'tok');
  assert.equal(e?.expiresAt.getTime(), exp.getTime());
});

test('google: cancelled but not yet expired keeps access until expiry', () => {
  const exp = new Date(now.getTime() + 10 * DAY);
  const e = entitlementFromGooglePurchase(play('SUBSCRIPTION_STATE_CANCELED', exp), 'expense_tracker_max_monthly', 'tok', now);
  assert.equal(e?.expiresAt.getTime(), exp.getTime());
});

test('google: grace period keeps access', () => {
  const exp = new Date(now.getTime() + 3 * DAY);
  const e = entitlementFromGooglePurchase(play('SUBSCRIPTION_STATE_IN_GRACE_PERIOD', exp), 'expense_tracker_max_monthly', 'tok', now);
  assert.equal(e?.expiresAt.getTime(), exp.getTime());
});

test('google: on hold, paused and pending have no access even with a future expiry', () => {
  const exp = new Date(now.getTime() + 20 * DAY);
  for (const s of ['SUBSCRIPTION_STATE_ON_HOLD', 'SUBSCRIPTION_STATE_PAUSED', 'SUBSCRIPTION_STATE_PENDING', 'SUBSCRIPTION_STATE_EXPIRED']) {
    const e = entitlementFromGooglePurchase(play(s, exp), 'expense_tracker_max_monthly', 'tok', now);
    assert.equal(e?.expiresAt.getTime(), now.getTime(), s);
  }
});

test('google: an already-past expiry stays in the past', () => {
  const exp = new Date(now.getTime() - 5 * DAY);
  const e = entitlementFromGooglePurchase(play('SUBSCRIPTION_STATE_EXPIRED', exp), 'expense_tracker_max_monthly', 'tok', now);
  assert.equal(e?.expiresAt.getTime(), exp.getTime());
});

test('google: unknown product or missing expiry gives nothing', () => {
  assert.equal(entitlementFromGooglePurchase(play('SUBSCRIPTION_STATE_ACTIVE', now, 'x'), 'x', 'tok', now), null);
  assert.equal(entitlementFromGooglePurchase({ subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE', lineItems: [] }, 'expense_tracker_max_monthly', 'tok', now), null);
});
