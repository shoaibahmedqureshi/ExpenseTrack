import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildInviteEmail } from './group_invite_email.ts';

const expires = new Date('2026-10-22T22:40:25Z');

test('subject names the inviter and the group', () => {
  const m = buildInviteEmail('Ann Lee', 'Goa trip', 'bob@x.com', expires);
  assert.equal(m.subject, 'Ann Lee invited you to "Goa trip" on Outlay');
});

test('body tells them how to join and which address to use', () => {
  const m = buildInviteEmail('Ann', 'Flat', 'bob@x.com', expires);
  assert.match(m.text, /Sign up with this email address: bob@x\.com/);
  assert.match(m.text, /apps\.apple\.com\/app\/id6790199113/);
  assert.match(m.text, /play\.google\.com\/store\/apps\/details\?id=com\.outlay\.app/);
  assert.match(m.text, /open until 22 October 2026/);
  assert.match(m.text, /If you do not know Ann, you can ignore this message/);
});

test('names cannot inject lines or markup into the subject or body', () => {
  const m = buildInviteEmail('Eve\r\nBcc: victim@x.com <script>', 'Group\nSubject: hi', 'bob@x.com', expires);
  assert.ok(!m.subject.includes('\n') && !m.subject.includes('\r'));
  assert.ok(!m.subject.includes('<') && !m.text.includes('<script>'));
  assert.ok(!/^Bcc:/m.test(m.text));
});

test('very long names are cut short', () => {
  const m = buildInviteEmail('A'.repeat(200), 'G'.repeat(200), 'bob@x.com', expires);
  assert.ok(m.subject.length < 140);
});

test('a missing inviter name falls back to a friendly default', () => {
  assert.match(buildInviteEmail('', 'Trip', 'bob@x.com', expires).subject, /^A friend invited you/);
});

test('an opt-out link is included when given, and only then', () => {
  const url = 'https://example.test/functions/v1/email_optout?t=abc.def';
  assert.match(buildInviteEmail('Ann', 'Flat', 'bob@x.com', expires, url).text, /Stop them here: https:\/\/example\.test\/functions\/v1\/email_optout\?t=abc\.def/);
  assert.ok(!/Stop them here/.test(buildInviteEmail('Ann', 'Flat', 'bob@x.com', expires).text));
});
