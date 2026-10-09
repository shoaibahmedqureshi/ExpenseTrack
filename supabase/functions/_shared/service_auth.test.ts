import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isServiceRole } from './service_auth.ts';

const jwt = (payload: object) => {
  const b = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${b({ alg: 'HS256', typ: 'JWT' })}.${b(payload)}.signature`;
};

test('a service-role token is accepted', () => {
  assert.equal(isServiceRole(`Bearer ${jwt({ role: 'service_role', ref: 'x' })}`), true);
});
test('the public anon token is refused', () => {
  assert.equal(isServiceRole(`Bearer ${jwt({ role: 'anon' })}`), false);
});
test('a signed-in user token is refused', () => {
  assert.equal(isServiceRole(`Bearer ${jwt({ role: 'authenticated', sub: 'u1' })}`), false);
});
test('missing, malformed and non-JWT credentials are refused', () => {
  for (const h of [null, '', 'Bearer', 'Bearer abc', 'Basic abc', 'Bearer a.b', `Bearer ${jwt({})}`, 'Bearer sb_secret_whatever']) {
    assert.equal(isServiceRole(h as string | null), false, String(h));
  }
});
test('the role must be exactly service_role', () => {
  assert.equal(isServiceRole(`Bearer ${jwt({ role: 'service_role_x' })}`), false);
  assert.equal(isServiceRole(`Bearer ${jwt({ role: ['service_role'] })}`), false);
});
test('scheme is case-insensitive', () => {
  assert.equal(isServiceRole(`bearer ${jwt({ role: 'service_role' })}`), true);
});
