import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildCreatorPitch, claimsFamiliarity, safeOpening } from './creator_pitch.ts';

const f = { handle: 'janedoe', niche: 'photography', subscribers: 20000, bio: '' };
test('flags claims of having watched or loved their content', () => {
  for (const t of ['I have been following your channel', 'Loved your video on lighting', 'your latest video was great', "I'm a huge fan", 'We watched your channel'])
    assert.equal(claimsFamiliarity(t), true, t);
  assert.equal(claimsFamiliarity('Your channel covers travel photography tips.'), false);
});
test('an invented claim falls back to a neutral opening', () => {
  assert.equal(safeOpening('I loved your latest video!', f), 'I came across your channel, which covers photography.');
  assert.equal(safeOpening('Check https://x.com now', f), 'I came across your channel, which covers photography.');
  assert.equal(safeOpening(undefined, f), 'I came across your channel, which covers photography.');
});
test('a grounded opening is kept', () => {
  assert.equal(safeOpening('Your channel teaches photo editing for beginners.', f), 'Your channel teaches photo editing for beginners.');
});
test('the pitch names every product, the creator page and an opt-out', () => {
  const p = buildCreatorPitch(f, 'Hello there.');
  assert.match(p.body, /Outlay Pro/);
  assert.match(p.body, /Stitchify Premium/);
  assert.match(p.body, /outlayapp\.net\/creators\.html/);
  assert.match(p.body, /won't contact you again/);
  assert.match(p.body, /^Hi janedoe,/);
});
