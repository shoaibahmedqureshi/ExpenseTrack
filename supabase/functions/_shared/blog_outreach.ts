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
  const pages = [guidelinesUrl, blogUrl, ...["/write-for-us", "/contribute", "/guest-post", "/contact", "/about", "/advertise", "/advertising", "/media-kit", "/work-with-us", "/sponsor"].map((p) => origin + p)];
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
  return `a free 1-year subscription to each of our products: ${PRODUCTS.map((p) => p.pitch).join(", and ")}`;
}

export const TRAFFIC_MIN = 1_000;
export const TRAFFIC_MAX = 50_000;

const NUM = String.raw`(\d{1,3}(?:,\d{3})+|\d+(?:\.\d+)?)\s*([km])?\+?`;
const KIND = String.raw`(?:monthly\s+|unique\s+|average\s+|avg\.?\s+)*(?:visitors|readers|users|sessions|visits)`;
const AFTER = new RegExp(`${NUM}\\s*${KIND}`, "gi");
const BEFORE = new RegExp(`(?:monthly|unique)\\s+(?:visitors|readers|users|sessions|visits)\\s*(?:[:\\-–—]|of|are|is)?\\s*${NUM}`, "gi");

function toCount(n: string, unit?: string): number {
  const v = parseFloat(n.replace(/,/g, ""));
  return Math.round(v * (unit?.toLowerCase() === "k" ? 1_000 : unit?.toLowerCase() === "m" ? 1_000_000 : 1));
}

/** A monthly visitor count the blog states about itself, from plain page text. Page views are ignored. */
export function parseTrafficClaim(html: string): number | null {
  const text = html.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/gi, " ").replace(/<[^>]+>/g, " ").replace(/&nbsp;/g, " ").replace(/\s+/g, " ");
  for (const re of [AFTER, BEFORE]) {
    re.lastIndex = 0;
    for (const m of text.matchAll(re)) {
      const around = text.slice(Math.max(0, m.index! - 40), m.index! + m[0].length + 40).toLowerCase();
      if (!/month|monthly|\/mo\b|per mo/.test(around) && !/monthly/.test(m[0].toLowerCase())) continue;
      const n = toCount(m[1], m[2]);
      if (n >= 100) return n;
    }
  }
  return null;
}

export function trafficFit(visitors: number | null): "unknown" | "in_range" | "out_of_range" {
  if (visitors == null) return "unknown";
  return visitors >= TRAFFIC_MIN && visitors <= TRAFFIC_MAX ? "in_range" : "out_of_range";
}

const PAID_SIGNALS: Array<[string, RegExp]> = [
  ["sells guest posts", /(paid|sponsored)\s+(guest\s+)?(post|article|content)s?|buy\s+(a\s+)?(guest\s+post|backlink|link)s?|guest\s+post(ing)?\s+(fee|price|pricing|cost|rates?|packages?|service)s?|we\s+charge|posting\s+fee/i],
  ["advertises do-follow links", /do-?\s?follow\s+(back)?links?|permanent\s+(back)?links?|links?\s+(placement|insertion)/i],
  ["quotes prices for posts", /\$\s?\d{2,4}\s*(usd)?\s*(per|for|\/)\s*(guest\s+)?(post|article|link)/i],
  ["accepts any topic", /(we|accepts?)\s+(accept|publish|welcome)s?\s+(guest\s+posts?\s+)?(on\s+)?(any|all)\s+(topic|niche|categor)/i],
];

export interface QualityInput { pages: Array<{ url: string; text: string }>; homeText: string; siblingPaths: Set<string>; guidelinesPath?: string }

const visible = (html: string) => html.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/gi, " ").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();

/** Flags that suggest a paid-link network or an empty site. Any flag makes the blog "suspect". */
export function qualityFlags(i: QualityInput): string[] {
  const flags: string[] = [];
  const all = i.pages.map((p) => visible(p.text)).join(" \n ");
  for (const [label, re] of PAID_SIGNALS) if (re.test(all)) flags.push(label);
  const home = visible(i.homeText);
  if (home.length < 1500) flags.push("thin home page");
  if (i.homeText && (i.homeText.match(/<article\b|<h2\b|<h3\b/gi)?.length ?? 0) < 3) flags.push("few visible articles");
  if (i.guidelinesPath && i.siblingPaths.has(i.guidelinesPath)) flags.push("same submission page as other blogs (network)");
  return flags;
}

/** /submit-finance-guest-post/ -> "submit-finance-guest-post" for comparing templates across domains. */
export function templatePath(u: string | null | undefined): string | undefined {
  if (!u) return undefined;
  try {
    const p = new URL(u).pathname.replace(/\/+$/, "").toLowerCase();
    return p && p !== "" && p.split("/").length <= 3 && /guest|write|contribut|submit/.test(p) ? p : undefined;
  } catch { return undefined; }
}
