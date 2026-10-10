import { test } from 'node:test';
import assert from 'node:assert/strict';
import { contactPaths, extractEmails, extractLinks, followable, isSafeUrl, parseTikTokProfile, pickEmail } from './contact_finder.ts';

test('finds plain, mailto and obfuscated addresses', () => {
  const html = '<a href="mailto:Collabs@Jane.com">x</a> or write jo [at] studio [dot] io';
  assert.deepEqual(extractEmails(html).sort(), ['collabs@jane.com', 'jo@studio.io']);
});
test('ignores asset names, placeholders and platform addresses', () => {
  const html = 'logo@2x.png noreply@a.com you@example.com bugs@sentry.io me@tiktok.com real@creator.co';
  assert.deepEqual(extractEmails(html), ['real@creator.co']);
});
test('decodes escaped @ from JSON', () => assert.deepEqual(extractEmails('biz\\u0040jane.com'), ['biz@jane.com']));
test('rejects unsafe URLs', () => {
  for (const u of ['http://a.com', 'https://localhost/x', 'https://127.0.0.1/', 'https://10.0.0.1/', 'https://user:p@a.com/', 'https://a.com:8080/', 'https://intranet/', 'https://box.internal/', 'file:///etc/passwd', 'not a url'])
    assert.equal(isSafeUrl(u), false, u);
  assert.equal(isSafeUrl('https://janedoe.com/contact'), true);
});
test('follows own sites and link-in-bio, not social platforms', () => {
  const l = extractLinks('<a href="https://www.instagram.com/jane">i</a><a href="https://linktr.ee/jane">l</a><a href="/about">a</a><a href="https://jane.com">j</a>', 'https://jane.com');
  assert.deepEqual(followable(l), ['https://linktr.ee/jane', 'https://jane.com/about', 'https://jane.com/']);
});
test('contact pages only on own domains, not link-in-bio', () => {
  assert.equal(contactPaths('https://linktr.ee/jane').length, 0);
  assert.equal(contactPaths('https://jane.com/x')[0], 'https://jane.com/contact');
});
test('prefers an address on the creator domain that looks like business', () => {
  assert.equal(pickEmail(['jane.private@gmail.com', 'collab@jane.com'], 'jane.com'), 'collab@jane.com');
  assert.equal(pickEmail([]), null);
});
test('reads TikTok bio and link', () => {
  const html = '..."uniqueId":"jane","signature":"Biz: a\\u0040b.com \\n photos","bioLink":{"link":"https:\\u002F\\u002Fjane.com","risk":1}...';
  const p = parseTikTokProfile(html);
  assert.equal(p.present, true);
  assert.equal(p.link, 'https://jane.com');
  assert.equal(parseTikTokProfile('<html>login</html>').present, false);
  assert.deepEqual(extractEmails(p.bio), ['a@b.com']);
});

import { extractUrls } from './contact_finder.ts';
test('finds links in free text and trims punctuation', () => {
  assert.deepEqual(extractUrls('Site: https://jane.com/shop. IG https://instagram.com/jane, bye'), ['https://jane.com/shop', 'https://instagram.com/jane']);
});
