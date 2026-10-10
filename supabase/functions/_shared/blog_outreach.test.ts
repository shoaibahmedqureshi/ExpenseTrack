import { test } from 'node:test';
import assert from 'node:assert/strict';
import { collectSearchUrls, filterCandidates, normalize, offerLine, pageSummary, pitchPages } from './blog_outreach.ts';

const content = [
  { type: 'text', text: 'hi' },
  { type: 'web_search_tool_result', content: [{ url: 'https://moneyblog.com/' }, { url: 'https://moneyblog.com/write-for-us' }, { url: 'https://other.org/x' }] },
];
test('collects only URLs the search tool returned', () => {
  const s = collectSearchUrls(content);
  assert.ok(s.has('https://moneyblog.com'));
  assert.ok(!s.has('https://invented.com'));
});
test('drops invented, unsafe and duplicate-site candidates', () => {
  const allowed = collectSearchUrls(content);
  const out = filterCandidates([
    { url: 'https://moneyblog.com/', blog_name: 'MB', guidelines_url: 'https://moneyblog.com/write-for-us' },
    { url: 'https://moneyblog.com/write-for-us' },
    { url: 'https://moneyblog.com/' , guidelines_url: 'https://evil.com/x' },
    { url: 'https://invented.com' },
    { url: 'http://other.org/x' },
  ], allowed);
  assert.equal(out.length, 1); // same site only once; invented and non-https sites dropped
  assert.equal(out[0].guidelines_url, 'https://moneyblog.com/write-for-us');
});
test('contact pages stay on the blog\'s own site', () => {
  const p = pitchPages('https://moneyblog.com/', 'https://evil.com/contact');
  assert.ok(p.every((u) => u.startsWith('https://moneyblog.com')));
  assert.ok(p.includes('https://moneyblog.com/contact'));
});
test('summarises title and description', () => {
  assert.equal(pageSummary('<title> My  Blog </title><meta name="description" content="Budget tips">'), 'My Blog — Budget tips');
  assert.equal(pageSummary('<p>none</p>'), '');
});
test('offer names every product', () => {
  assert.match(offerLine(), /Outlay Pro/);
  assert.match(offerLine(), /Stitchify Premium/);
  assert.equal(normalize('https://a.com/x/#y'), 'https://a.com/x');
});
