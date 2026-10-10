import { test } from 'node:test';
import assert from 'node:assert/strict';
import { asoFindings, asoSnapshot, auditHtml, diffFindings, parseSitemap, sitemapGaps, topSeverity } from './seo_audit.ts';

const good = `<html lang="en"><head><title>Outlay: simple expense tracker for everyone</title>
<meta name="description" content="${'Track spending, set budgets and share costs with family. '.repeat(2)}">
<meta name="viewport" content="width=device-width"><link rel="canonical" href="https://x.com/">
<meta property="og:title" content="a"><meta property="og:description" content="b"><meta property="og:image" content="c"></head>
<body><h1>Hi</h1><img src="a.png" alt="a"></body></html>`;
test('a well-formed page has no findings', () => assert.deepEqual(auditHtml(good, 'https://x.com/'), []));
test('missing basics are found with severity', () => {
  const f = auditHtml('<html><head></head><body><h1>a</h1><h1>b</h1><img src="x.png"></body></html>', 'u');
  const checks = f.map((x) => x.check);
  for (const c of ['title', 'meta description', 'h1', 'canonical', 'lang', 'viewport', 'open graph', 'image alt text']) assert.ok(checks.includes(c), c);
  assert.equal(topSeverity(f), 'high');
});
test('noindex is flagged high', () => {
  assert.ok(auditHtml(good.replace('<title>', '<meta name="robots" content="noindex"><title>'), 'u').some((x) => x.check === 'robots' && x.severity === 'high'));
});
test('sitemap parsing and hreflang gaps', () => {
  const xml = '<urlset><url><loc>https://x.com/a</loc><xhtml:link hreflang="ur" href="https://x.com/ur/a"/></url></urlset>';
  assert.deepEqual(parseSitemap(xml), ['https://x.com/a']);
  assert.deepEqual(sitemapGaps(xml), ['https://x.com/ur/a']);
});
test('diff reports new and resolved findings', () => {
  const a = { check: 'title', severity: 'high' as const, detail: 'Missing', url: 'u' };
  const b = { check: 'h1', severity: 'low' as const, detail: 'two', url: 'u' };
  const d = diffFindings([a], [b]);
  assert.deepEqual(d.added, [b]); assert.deepEqual(d.resolved, [a]);
});
test('app store snapshot and findings', () => {
  const s = asoSnapshot({ results: [{ trackName: 'Outlay - Expense Tracker & Budget Planner', version: '1.1.0', averageUserRating: 5, userRatingCount: 2, screenshotUrls: ['a', 'b'], description: 'short', currentVersionReleaseDate: '2026-01-01T00:00:00Z' }] }, Date.parse('2026-10-10'))!;
  const checks = asoFindings(s).map((x) => x.check);
  for (const c of ['store title', 'ratings', 'screenshots', 'description', 'freshness']) assert.ok(checks.includes(c), c);
  assert.equal(asoSnapshot({ results: [] }), null);
});
