import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { requireServiceRole } from "../_shared/service_auth.ts";
import { fetchPage } from "../_shared/safe_fetch.ts";
import {
  asoFindings, asoSnapshot, auditHtml, diffFindings, parseSitemap, sitemapGaps, topSeverity, type Finding,
} from "../_shared/seo_audit.ts";

// SEO/ASO agent: checks our own website and App Store listing and records what is wrong and what changed.
// It publishes and posts nothing anywhere.

const supabase = createClient(Deno.env.get("SUPABASE_URL") || "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "");
const SITE = Deno.env.get("SEO_SITE") || "https://outlayapp.net";
const BUNDLE_ID = Deno.env.get("IOS_BUNDLE_ID") || "com.codebloom.outlay";
const MAX_PAGES = 40;

async function previousFindings(appDomain: string, type: string): Promise<Finding[]> {
  const { data } = await supabase.from("guest_post_audits").select("findings").eq("app_domain", appDomain).eq("audit_type", type)
    .order("created_at", { ascending: false }).limit(1);
  const items = data?.[0]?.findings?.items;
  return Array.isArray(items) ? items : [];
}

async function save(appDomain: string, type: string, items: Finding[], extra: Record<string, unknown>) {
  const prev = await previousFindings(appDomain, type);
  const change = diffFindings(prev, items);
  const { error } = await supabase.from("guest_post_audits").insert({
    app_domain: appDomain, audit_type: type, findings: { items, ...extra },
    recommendations: { new: change.added, resolved: change.resolved, first_run: prev.length === 0 },
    priority: items.length ? topSeverity(items) : "low", status: "open",
  });
  if (error) throw new Error(`${type} save: ${error.message}`);
  return { items: items.length, new: change.added.length, resolved: change.resolved.length };
}

async function auditSite() {
  const host = new URL(SITE).hostname;
  const findings: Finding[] = [];
  const sitemap = await fetchPage(`${SITE}/sitemap.xml`, { allowXml: true });
  let urls: string[] = [];
  if (!sitemap) {
    findings.push({ check: "sitemap", severity: "high", detail: "sitemap.xml is not reachable" });
  } else {
    urls = parseSitemap(sitemap.text).filter((u) => { try { return new URL(u).hostname === host; } catch { return false; } }).slice(0, MAX_PAGES);
    for (const gap of sitemapGaps(sitemap.text)) findings.push({ check: "sitemap", severity: "low", detail: "hreflang alternate is not listed as its own page", url: gap });
  }
  const robots = await fetch(`${SITE}/robots.txt`, { signal: AbortSignal.timeout(8000) }).then((r) => r.ok ? r.text() : null).catch(() => null);
  if (robots === null) findings.push({ check: "robots.txt", severity: "medium", detail: "robots.txt is not reachable" });
  else if (/disallow:\s*\/\s*$/im.test(robots)) findings.push({ check: "robots.txt", severity: "high", detail: "robots.txt blocks the whole site" });

  if (!urls.length) urls = [SITE + "/"];
  let checked = 0;
  for (const u of urls) {
    const page = await fetchPage(u);
    if (!page) { findings.push({ check: "page reachable", severity: "high", detail: "Page could not be loaded", url: u }); continue; }
    checked++;
    findings.push(...auditHtml(page.text, u));
    await new Promise((r) => setTimeout(r, 200));
  }
  return { result: await save(host, "seo", findings, { pages_checked: checked, pages_listed: urls.length }), pages: checked };
}

async function auditAppStore() {
  const res = await fetch(`https://itunes.apple.com/lookup?bundleId=${encodeURIComponent(BUNDLE_ID)}`, { signal: AbortSignal.timeout(10000) });
  if (!res.ok) throw new Error(`App Store lookup ${res.status}`);
  const snap = asoSnapshot(await res.json());
  if (!snap) return { result: await save(`app-store:${BUNDLE_ID}`, "aso", [{ check: "listing", severity: "high", detail: "App not found in the App Store lookup" }], {}), snapshot: null };
  return { result: await save(`app-store:${BUNDLE_ID}`, "aso", asoFindings(snap), { snapshot: snap, google_play: "not checked: no public API" }), snapshot: snap };
}

async function main() {
  const out: Record<string, unknown> = {};
  const failures: string[] = [];
  for (const [name, run] of [["site", auditSite], ["app_store", auditAppStore]] as const) {
    try { out[name] = await run(); } catch (e) { failures.push(`${name}: ${String(e)}`); }
  }
  await supabase.from("agent_logs").insert({
    agent_type: "seo_aso", action: "audit", status: failures.length ? "error" : "success",
    details: JSON.parse(JSON.stringify(out)), error_message: failures.length ? failures.join(" | ").slice(0, 2000) : null,
  });
  return { status: failures.length ? "error" : "success", failures, ...out };
}

Deno.serve(async (req) => {
  const denied = requireServiceRole(req);
  if (denied) return denied;
  const result = await main();
  return new Response(JSON.stringify(result), { headers: { "Content-Type": "application/json" }, status: result.status === "success" ? 200 : 500 });
});
