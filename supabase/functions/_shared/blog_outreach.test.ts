import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseTrafficClaim, trafficFit, collectSearchUrls, filterCandidates, normalize, offerLine, pageSummary, pitchPages } from './blog_outreach.ts';

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

test('reads stated monthly visitors in several phrasings', () => {
  assert.equal(parseTrafficClaim('<p>We reach 25,000 monthly visitors.</p>'), 25000);
  assert.equal(parseTrafficClaim('Over 12k unique visitors per month'), 12000);
  assert.equal(parseTrafficClaim('Monthly visitors: 8,500'), 8500);
  assert.equal(parseTrafficClaim('1.2M readers a month'), 1200000);
});
test('ignores page views, tiny numbers and non-monthly claims', () => {
  assert.equal(parseTrafficClaim('300,000 page views per month'), null);
  assert.equal(parseTrafficClaim('5 visitors per month'), null);
  assert.equal(parseTrafficClaim('We had 40,000 visitors last year'), null);
  assert.equal(parseTrafficClaim('<script>var a="90,000 monthly visitors"</script>'), null);
});
test('fits the 1k-50k target', () => {
  assert.equal(trafficFit(1000), 'in_range');
  assert.equal(trafficFit(50000), 'in_range');
  assert.equal(trafficFit(999), 'out_of_range');
  assert.equal(trafficFit(120000), 'out_of_range');
  assert.equal(trafficFit(null), 'unknown');
});

import { qualityFlags, templatePath } from './blog_outreach.ts';
const rich = '<h2>a</h2><h2>b</h2><h3>c</h3>' + '<p>' + 'real article text about money and habits. '.repeat(60) + '</p>';
test('a normal blog has no flags', () => {
  assert.deepEqual(qualityFlags({ pages: [{ url: 'u', text: rich }], homeText: rich, siblingPaths: new Set() }), []);
});
test('paid-post pages and prices are flagged', () => {
  const f = qualityFlags({ pages: [{ url: 'u', text: '<p>Guest post fee: $80 per post, permanent dofollow links</p>' }], homeText: rich, siblingPaths: new Set() });
  assert.ok(f.includes('sells guest posts'));
  assert.ok(f.includes('advertises do-follow links'));
  assert.ok(f.includes('quotes prices for posts'));
});
test('thin sites and shared templates are flagged', () => {
  const f = qualityFlags({ pages: [], homeText: '<p>tiny</p>', siblingPaths: new Set(['/submit-finance-guest-post']), guidelinesPath: '/submit-finance-guest-post' });
  assert.ok(f.includes('thin home page'));
  assert.ok(f.some((x) => x.includes('network')));
});
test('template path ignores deep or unrelated URLs', () => {
  assert.equal(templatePath('https://a.com/submit-finance-guest-post/'), '/submit-finance-guest-post');
  assert.equal(templatePath('https://a.com/2024/03/some-long-article'), undefined);
});
