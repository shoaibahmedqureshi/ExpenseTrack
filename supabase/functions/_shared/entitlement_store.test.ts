import { test } from 'node:test';
import assert from 'node:assert/strict';
import type { Entitlement } from './entitlement.ts';
import { endEntitlement, linkEntitlement, refreshEntitlement } from './entitlement_store.ts';

type Row = Record<string, any>;

// Just enough of the supabase-js query builder for the calls entitlement_store makes, over an in-memory table.
function fakeAdmin(initial: Row[] = []) {
  const rows: Row[] = initial.map((r) => ({ ...r }));
  const builder = (mode: 'select' | 'update' | 'delete', patch?: Row) => {
    const filters: Array<[string, unknown]> = [];
    const match = () => rows.filter((r) => filters.every(([k, v]) => r[k] === v));
    const api: any = {
      eq(k: string, v: unknown) { filters.push([k, v]); return api; },
      select() { return api; },
      async maybeSingle() { return { data: match()[0] ?? null, error: null }; },
      then(resolve: (v: unknown) => void) {
        if (mode === 'update') match().forEach((r) => Object.assign(r, patch));
        if (mode === 'delete') for (const r of match()) rows.splice(rows.indexOf(r), 1);
        resolve({ error: null });
      },
    };
    return api;
  };
  const admin: any = {
    from: () => ({
      select: () => builder('select'),
      update: (patch: Row) => builder('update', patch),
      delete: () => builder('delete'),
      async upsert(row: Row) {
        const i = rows.findIndex((r) => r.user_id === row.user_id);
        if (i >= 0) rows[i] = { ...rows[i], ...row }; else rows.push({ ...row });
        return { error: null };
      },
    }),
  };
  return { admin, rows };
}

const DAY = 86_400_000;
const ent = (over: Partial<Entitlement> = {}): Entitlement => ({
  plan: 'max_monthly',
  productId: 'expense_tracker_max_monthly',
  originalTransactionId: 'T1',
  expiresAt: new Date(Date.now() + 30 * DAY),
  ...over,
});

test('links a verified entitlement to the signed-in user', async () => {
  const { admin, rows } = fakeAdmin();
  assert.equal(await linkEntitlement(admin, 'u1', 'apple', ent()), 'ok');
  assert.equal(rows.length, 1);
  assert.equal(rows[0].user_id, 'u1');
  assert.equal(rows[0].plan, 'max_monthly');
  assert.equal(rows[0].store, 'apple');
});

test('syncing again by the same user updates the row instead of duplicating it', async () => {
  const { admin, rows } = fakeAdmin();
  await linkEntitlement(admin, 'u1', 'apple', ent());
  await linkEntitlement(admin, 'u1', 'apple', ent({ plan: 'max_annual', expiresAt: new Date(Date.now() + 365 * DAY) }));
  assert.equal(rows.length, 1);
  assert.equal(rows[0].plan, 'max_annual');
});

test('a second account cannot claim a subscription that is still current', async () => {
  const { admin, rows } = fakeAdmin();
  await linkEntitlement(admin, 'u1', 'apple', ent());
  assert.equal(await linkEntitlement(admin, 'u2', 'apple', ent()), 'claimed');
  assert.equal(rows.length, 1);
  assert.equal(rows[0].user_id, 'u1');
});

test('once the first holder has expired, another account can take over', async () => {
  const { admin, rows } = fakeAdmin();
  await linkEntitlement(admin, 'u1', 'apple', ent({ expiresAt: new Date(Date.now() - DAY) }));
  assert.equal(await linkEntitlement(admin, 'u2', 'apple', ent()), 'ok');
  assert.equal(rows.length, 1);
  assert.equal(rows[0].user_id, 'u2');
});

test('the same transaction id on different stores is not a conflict', async () => {
  const { admin, rows } = fakeAdmin();
  await linkEntitlement(admin, 'u1', 'apple', ent());
  assert.equal(await linkEntitlement(admin, 'u2', 'google', ent()), 'ok');
  assert.equal(rows.length, 2);
});

test('a webhook refresh updates only the matching subscription, and does nothing when none matches', async () => {
  const { admin, rows } = fakeAdmin();
  await linkEntitlement(admin, 'u1', 'apple', ent());
  await linkEntitlement(admin, 'u2', 'apple', ent({ originalTransactionId: 'T2' }));
  const later = new Date(Date.now() + 60 * DAY);
  await refreshEntitlement(admin, 'apple', ent({ expiresAt: later }));
  assert.equal(rows.find((r) => r.user_id === 'u1')!.expires_at, later.toISOString());
  assert.notEqual(rows.find((r) => r.user_id === 'u2')!.expires_at, later.toISOString());
  await refreshEntitlement(admin, 'apple', ent({ originalTransactionId: 'nobody' }));
  assert.equal(rows.length, 2);
});

test('a refund ends access now', async () => {
  const { admin, rows } = fakeAdmin();
  await linkEntitlement(admin, 'u1', 'google', ent({ originalTransactionId: 'tok' }));
  await endEntitlement(admin, 'google', 'tok');
  assert.ok(new Date(rows[0].expires_at).getTime() <= Date.now());
});
