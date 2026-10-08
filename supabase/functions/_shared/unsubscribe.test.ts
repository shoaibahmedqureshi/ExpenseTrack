import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeUnsubscribeToken, verifyUnsubscribeToken } from './unsubscribe.ts';

const SECRET = 'test-secret-value';

test('a token verifies back to the lower-cased address', async () => {
  const t = await makeUnsubscribeToken(SECRET, ' Bob@Example.COM ');
  assert.equal(await verifyUnsubscribeToken(SECRET, t), 'bob@example.com');
});

test('a token made with another secret is rejected', async () => {
  const t = await makeUnsubscribeToken('other-secret', 'bob@example.com');
  assert.equal(await verifyUnsubscribeToken(SECRET, t), null);
});

test('changing the address in a token breaks it', async () => {
  const t = await makeUnsubscribeToken(SECRET, 'bob@example.com');
  const sig = t.split('.')[1];
  const forged = `${btoa('victim@example.com').replace(/=+$/, '')}.${sig}`;
  assert.equal(await verifyUnsubscribeToken(SECRET, forged), null);
});

test('malformed input is rejected, not thrown', async () => {
  for (const bad of ['', 'abc', 'a.b.c', '.', 'x.', '.y', '%%%.%%%', 'A'.repeat(700)]) {
    assert.equal(await verifyUnsubscribeToken(SECRET, bad), null, bad.slice(0, 10));
  }
});

test('an empty secret can neither make nor verify a token', async () => {
  await assert.rejects(() => makeUnsubscribeToken('', 'bob@example.com'), /UNSUBSCRIBE_SECRET/);
  const t = await makeUnsubscribeToken(SECRET, 'bob@example.com');
  assert.equal(await verifyUnsubscribeToken('', t), null);
});
