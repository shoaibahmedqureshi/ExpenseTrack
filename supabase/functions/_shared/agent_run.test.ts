import { test } from 'node:test';
import assert from 'node:assert/strict';
import { checked, newStats, parseModelJson } from './agent_run.ts';

test('plain JSON parses', () => assert.deepEqual(parseModelJson('[{"a":1}]'), [{ a: 1 }]));
test('fenced JSON parses', () =>
  assert.deepEqual(parseModelJson('```json\n[{"a":1}]\n```'), [{ a: 1 }]));
test('JSON inside prose parses', () =>
  assert.deepEqual(parseModelJson('Here you go:\n[{"a":1}]\nHope it helps'), [{ a: 1 }]));
test('text without JSON throws', () => assert.throws(() => parseModelJson('sorry, no')));

test('a rejected write is recorded, not ignored', async () => {
  const s = newStats();
  const ok = await checked(s, 'insert x', Promise.resolve({ error: { message: 'column "platform" does not exist' } }));
  assert.equal(ok, false);
  assert.deepEqual(s.failures, ['insert x: column "platform" does not exist']);
});
test('a thrown write is recorded', async () => {
  const s = newStats();
  await checked(s, 'insert y', Promise.reject(new Error('boom')));
  assert.equal(s.failures.length, 1);
});
test('a good write counts', async () => {
  const s = newStats();
  assert.equal(await checked(s, 'ok', Promise.resolve({ error: null })), true);
  assert.equal(s.ok, 1);
});
