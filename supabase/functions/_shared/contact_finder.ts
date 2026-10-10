// Finds a business email a creator published themselves. Pure helpers; network code lives in the function.

const EMAIL_RE = /[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}/g;
const JUNK_LOCAL = /^(noreply|no-reply|donotreply|do-not-reply|example|test|user|name|email|your|you|webmaster|abuse|postmaster|privacy|legal|support@wix)/i;
const JUNK_DOMAIN = /(^|\.)(example\.(com|org)|sentry\.io|wixpress\.com|wix\.com|schema\.org|w3\.org|tiktok\.com|instagram\.com|facebook\.com|google\.com|squarespace\.com|godaddy\.com|domain\.com|email\.com)$/i;
const ASSET_TAIL = /\.(png|jpe?g|gif|webp|svg|css|js)$/i;
const LINK_IN_BIO = /(^|\.)(linktr\.ee|beacons\.ai|bio\.link|campsite\.bio|carrd\.co|lnk\.bio|stan\.store|solo\.to|linkin\.bio|taplink\.cc|withkoji\.com|milkshake\.app)$/i;
const SOCIAL = /(^|\.)(tiktok|instagram|facebook|twitter|x|youtube|youtu|linkedin|pinterest|snapchat|threads|patreon|spotify|apple|amazon|amzn|etsy|shopify|bit)\.(com|be|to|ly|net|co)$/i;

export function decodeHtml(s: string): string {
  return s
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(parseInt(d, 10)))
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'")
    .replace(/\\u0040/gi, "@").replace(/\\u002F/gi, "/");
}

/** Emails written plainly, as mailto: links, or lightly obfuscated ("name [at] site [dot] com"). */
export function extractEmails(raw: string): string[] {
  const text = decodeHtml(raw)
    .replace(/\s*[\[(]\s*at\s*[\])]\s*/gi, "@")
    .replace(/\s*[\[(]\s*dot\s*[\])]\s*/gi, ".");
  const found = new Set<string>();
  for (const m of text.matchAll(EMAIL_RE)) {
    const e = m[0].toLowerCase().replace(/[.]+$/, "");
    const [local, domain] = e.split("@");
    if (!local || !domain || ASSET_TAIL.test(e) || JUNK_LOCAL.test(local) || JUNK_DOMAIN.test(domain)) continue;
    found.add(e);
  }
  return [...found];
}

/** Absolute http(s) links found in href attributes or bare URLs. */
export function extractLinks(html: string, base: string): string[] {
  const out = new Set<string>();
  for (const m of decodeHtml(html).matchAll(/href\s*=\s*["']([^"'#]+)["']/gi)) {
    try { out.add(new URL(m[1], base).toString()); } catch { /* ignore */ }
  }
  return [...out];
}

/** Only public https hosts: no credentials, IP literals, localhost or internal names. */
export function isSafeUrl(u: string): boolean {
  let url: URL;
  try { url = new URL(u); } catch { return false; }
  if (url.protocol !== "https:" || url.username || url.password) return false;
  if (url.port && url.port !== "443") return false;
  const h = url.hostname.toLowerCase();
  if (!h.includes(".") || h === "localhost" || /^[\d.]+$/.test(h) || h.includes(":") || h.startsWith("[")) return false;
  if (/\.(local|internal|localdomain|lan|home|corp|test|invalid)$/.test(h)) return false;
  return true;
}

export const isLinkInBio = (u: string) => { try { return LINK_IN_BIO.test(new URL(u).hostname); } catch { return false; } };
export const isSocial = (u: string) => { try { return SOCIAL.test(new URL(u).hostname); } catch { return false; } };

/** The creator's own site or link-in-bio page, worth reading. */
export function followable(links: string[]): string[] {
  return links.filter((l) => isSafeUrl(l) && (isLinkInBio(l) || !isSocial(l))).slice(0, 4);
}

/** Pages on the creator's own domain that usually carry a business address. */
export function contactPaths(site: string): string[] {
  try {
    const u = new URL(site);
    if (isLinkInBio(site)) return [];
    return ["/contact", "/about", "/business"].map((p) => new URL(p, u.origin).toString());
  } catch { return []; }
}

const BUSINESS_HINT = /(business|collab|partner|contact|hello|hi|info|inquir|enquir|work|pr|press|media|mgmt|management|booking)/i;

/** Prefer an address that looks like a business contact; first seen wins otherwise. */
export function pickEmail(candidates: string[], ownDomain?: string): string | null {
  if (!candidates.length) return null;
  const score = (e: string) => {
    const [local, domain] = e.split("@");
    return (ownDomain && domain.endsWith(ownDomain) ? 2 : 0) + (BUSINESS_HINT.test(local) ? 1 : 0);
  };
  return [...candidates].sort((a, b) => score(b) - score(a))[0];
}

/** TikTok embeds the profile as JSON: signature (bio) and bioLink. */
export function parseTikTokProfile(html: string): { present: boolean; bio: string; link: string | null } {
  const sig = html.match(/"signature":"((?:[^"\\]|\\.)*)"/);
  const link = html.match(/"bioLink":\{"link":"((?:[^"\\]|\\.)*)"/);
  const un = (s: string) => { try { return JSON.parse(`"${s}"`) as string; } catch { return s; } };
  return { present: /"uniqueId":"/.test(html) && !!sig, bio: sig ? un(sig[1]) : "", link: link ? un(link[1]) : null };
}

/** https links written in free text (channel descriptions, bios). */
export function extractUrls(text: string): string[] {
  const out = new Set<string>();
  for (const m of decodeHtml(text).matchAll(/https?:\/\/[^\s<>"')\]]+/gi)) {
    const u = m[0].replace(/[.,;:!?]+$/, "");
    try { out.add(new URL(u).toString()); } catch { /* ignore */ }
  }
  return [...out];
}
