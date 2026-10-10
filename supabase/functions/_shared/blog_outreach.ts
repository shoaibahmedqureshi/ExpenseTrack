// Pure helpers for blog discovery and guest-post pitching.
import { isSafeUrl } from "./contact_finder.ts";

export const PRODUCTS = [
  { name: "Outlay", pitch: "Outlay Pro, our expense-tracking and budgeting app" },
  { name: "Stitchify", pitch: "Stitchify Premium, our photo-combining app" },
] as const;

/** Every URL the web-search tool actually returned; model-written URLs are never trusted. */
export function collectSearchUrls(content: Array<Record<string, unknown>>): Set<string> {
  const urls = new Set<string>();
  for (const block of content) {
    if (block.type !== "web_search_tool_result" || !Array.isArray(block.content)) continue;
    for (const r of block.content as Array<Record<string, unknown>>) {
      if (typeof r.url === "string") urls.add(normalize(r.url));
    }
  }
  return urls;
}

export function normalize(u: string): string {
  try {
    const x = new URL(u);
    x.hash = "";
    return x.toString().replace(/\/$/, "");
  } catch { return u; }
}

export const siteOf = (u: string) => { try { return new URL(u).hostname.replace(/^www\./, ""); } catch { return ""; } };

/** Pages on the blog's own site that usually state a contact or guest-post address. */
export function pitchPages(blogUrl: string, guidelinesUrl?: string | null): string[] {
  let origin: string;
  try { origin = new URL(blogUrl).origin; } catch { return []; }
  const pages = [guidelinesUrl, blogUrl, ...["/write-for-us", "/contribute", "/guest-post", "/contact", "/about", "/advertise"].map((p) => origin + p)];
  const seen = new Set<string>();
  return pages.filter((p): p is string => !!p && isSafeUrl(p) && siteOf(p) === siteOf(blogUrl) && !seen.has(p) && !!seen.add(p));
}

/** Keeps only candidates on a site the search tool returned (the model often names the home page of a result), on safe hosts, de-duplicated by site. */
export function filterCandidates(
  cands: Array<{ blog_name?: string; url?: string; topic?: string; guidelines_url?: string }>,
  allowed: Set<string>,
) {
  const sites = new Set<string>();
  const allowedSites = new Set([...allowed].map(siteOf));
  const out: typeof cands = [];
  for (const c of cands) {
    if (!c.url) continue;
    const url = normalize(c.url);
    if (!allowedSites.has(siteOf(url)) || !isSafeUrl(url)) continue;
    const site = siteOf(url);
    if (!site || sites.has(site)) continue;
    sites.add(site);
    out.push({ ...c, url, guidelines_url: c.guidelines_url && siteOf(c.guidelines_url) === site && isSafeUrl(c.guidelines_url) ? normalize(c.guidelines_url) : undefined });
  }
  return out;
}

/** Title and meta description, the only facts about a blog the pitch may rely on. */
export function pageSummary(html: string): string {
  const title = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1] ?? "";
  const desc = html.match(/<meta[^>]+name=["']description["'][^>]+content=["']([^"']*)["']/i)?.[1]
    ?? html.match(/<meta[^>]+content=["']([^"']*)["'][^>]+name=["']description["']/i)?.[1] ?? "";
  return `${title.replace(/\s+/g, " ").trim()} — ${desc.replace(/\s+/g, " ").trim()}`.replace(/^ — | — $/g, "").slice(0, 400);
}

export function offerLine(): string {
  return `a free 1-year subscription to each of our products: ${PRODUCTS.map((p) => p.pitch).join(" and ")}`;
}
