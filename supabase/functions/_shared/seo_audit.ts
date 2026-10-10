// Deterministic SEO / ASO checks. No model involved: every finding is something that can be verified on the page.

export type Severity = "high" | "medium" | "low";
export interface Finding { check: string; severity: Severity; detail: string; url?: string }

const attr = (tag: string, name: string) => tag.match(new RegExp(`${name}\\s*=\\s*["']([^"']*)["']`, "i"))?.[1];
const metaContent = (html: string, key: string, by: "name" | "property" = "name") => {
  for (const m of html.matchAll(/<meta\b[^>]*>/gi)) if (attr(m[0], by)?.toLowerCase() === key) return attr(m[0], "content") ?? "";
  return undefined;
};

export function auditHtml(html: string, url: string): Finding[] {
  const f: Finding[] = [];
  const add = (check: string, severity: Severity, detail: string) => f.push({ check, severity, detail, url });
  const title = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1]?.replace(/\s+/g, " ").trim();
  if (!title) add("title", "high", "Missing <title>");
  else if (title.length < 25) add("title", "medium", `Title is short (${title.length} characters)`);
  else if (title.length > 65) add("title", "low", `Title may be cut off in results (${title.length} characters)`);

  const desc = metaContent(html, "description");
  if (desc === undefined || !desc.trim()) add("meta description", "high", "Missing meta description");
  else if (desc.length < 70) add("meta description", "medium", `Meta description is short (${desc.length} characters)`);
  else if (desc.length > 165) add("meta description", "low", `Meta description may be cut off (${desc.length} characters)`);

  const h1 = (html.match(/<h1\b/gi) || []).length;
  if (h1 === 0) add("h1", "medium", "No <h1> heading");
  else if (h1 > 1) add("h1", "low", `${h1} <h1> headings; one is clearer`);

  if (!/<link\b[^>]*rel=["']canonical["']/i.test(html)) add("canonical", "medium", "No canonical link");
  if (!/<html\b[^>]*\blang=/i.test(html)) add("lang", "medium", "<html> has no lang attribute");
  if (metaContent(html, "viewport") === undefined) add("viewport", "high", "No viewport meta tag (bad on phones)");
  if (/noindex/i.test(metaContent(html, "robots") ?? "")) add("robots", "high", "Page is marked noindex");
  for (const k of ["og:title", "og:description", "og:image"]) if (metaContent(html, k, "property") === undefined) add("open graph", "low", `Missing ${k} (poor link previews)`);

  const imgs = [...html.matchAll(/<img\b[^>]*>/gi)].map((m) => m[0]);
  const noAlt = imgs.filter((t) => attr(t, "alt") === undefined).length;
  if (noAlt) add("image alt text", "medium", `${noAlt} of ${imgs.length} images have no alt attribute`);
  return f;
}

export function parseSitemap(xml: string): string[] {
  return [...xml.matchAll(/<loc>\s*([^<\s]+)\s*<\/loc>/gi)].map((m) => m[1]);
}

/** hreflang alternates listed in a sitemap that are not themselves pages in it. */
export function sitemapGaps(xml: string): string[] {
  const locs = new Set(parseSitemap(xml));
  const gaps = new Set<string>();
  for (const m of xml.matchAll(/hreflang=["'][^"']+["'][^>]*href=["']([^"']+)["']/gi)) if (!locs.has(m[1])) gaps.add(m[1]);
  return [...gaps];
}

const rank: Record<Severity, number> = { high: 3, medium: 2, low: 1 };
export const topSeverity = (f: Finding[]): Severity => f.reduce<Severity>((a, x) => (rank[x.severity] > rank[a] ? x.severity : a), "low");
const key = (x: Finding) => `${x.check}|${x.url ?? ""}|${x.detail}`;

/** What changed since the previous run. */
export function diffFindings(prev: Finding[], now: Finding[]) {
  const before = new Set(prev.map(key)), after = new Set(now.map(key));
  return { added: now.filter((x) => !before.has(key(x))), resolved: prev.filter((x) => !after.has(key(x))) };
}

export interface AsoSnapshot { name: string; version: string; rating: number; ratingCount: number; screenshots: number; descriptionLength: number; updatedDaysAgo: number | null }

export function asoSnapshot(lookup: { results?: Array<Record<string, unknown>> }, now = Date.now()): AsoSnapshot | null {
  const r = lookup.results?.[0];
  if (!r) return null;
  const updated = typeof r.currentVersionReleaseDate === "string" ? Date.parse(r.currentVersionReleaseDate) : NaN;
  return {
    name: String(r.trackName ?? ""), version: String(r.version ?? ""),
    rating: Number(r.averageUserRating ?? 0), ratingCount: Number(r.userRatingCount ?? 0),
    screenshots: Array.isArray(r.screenshotUrls) ? r.screenshotUrls.length : 0,
    descriptionLength: String(r.description ?? "").length,
    updatedDaysAgo: Number.isNaN(updated) ? null : Math.floor((now - updated) / 86_400_000),
  };
}

export function asoFindings(s: AsoSnapshot, store = "App Store"): Finding[] {
  const f: Finding[] = [];
  const add = (check: string, severity: Severity, detail: string) => f.push({ check, severity, detail });
  if (s.name.length > 30) add("store title", "medium", `${store} title is ${s.name.length} characters; stores show about 30`);
  if (s.ratingCount < 10) add("ratings", "high", `Only ${s.ratingCount} ratings; few ratings hurts conversion and ranking`);
  else if (s.rating && s.rating < 4) add("ratings", "high", `Average rating is ${s.rating.toFixed(1)}`);
  if (s.screenshots < 5) add("screenshots", "medium", `${s.screenshots} screenshots; 5 or more tell the story better`);
  if (s.descriptionLength < 500) add("description", "medium", `Description is short (${s.descriptionLength} characters)`);
  if (s.updatedDaysAgo != null && s.updatedDaysAgo > 90) add("freshness", "low", `Last update was ${s.updatedDaysAgo} days ago`);
  return f;
}
