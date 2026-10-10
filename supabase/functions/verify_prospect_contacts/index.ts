import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { fetchPage } from "../_shared/safe_fetch.ts";
import { requireServiceRole } from "../_shared/service_auth.ts";
import {
  contactPaths, extractEmails, extractLinks, extractUrls, followable, isLinkInBio, isSafeUrl, parseTikTokProfile, pickEmail,
} from "../_shared/contact_finder.ts";

const supabase = createClient(Deno.env.get("SUPABASE_URL") || "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "");

const BATCH = 12;
interface Outcome { email: string | null; source: string | null; note: string }

/** Reads the creator's own linked pages (site, contact page, link-in-bio) for a published address. */
async function readSites(sites: string[]): Promise<Outcome> {
  const visited = new Set<string>();
  for (const site of sites) {
    const pages = [site, ...(isLinkInBio(site) ? [] : contactPaths(site))];
    for (const p of pages) {
      if (visited.has(p)) continue;
      visited.add(p);
      const page = await fetchPage(p);
      if (!page) continue;
      let host = "";
      try { host = new URL(page.url).hostname.replace(/^www\./, ""); } catch { /* ignore */ }
      const found = pickEmail(extractEmails(page.text), isLinkInBio(page.url) ? undefined : host);
      if (found) return { email: found, source: page.url, note: "found on the creator's linked page" };

      // One more hop from a link-in-bio page to the creator's own site.
      if (isLinkInBio(page.url)) {
        for (const next of followable(extractLinks(page.text, page.url)).filter((u) => !isLinkInBio(u)).slice(0, 2)) {
          for (const q of [next, ...contactPaths(next)]) {
            if (visited.has(q)) continue;
            visited.add(q);
            const sub = await fetchPage(q);
            if (!sub) continue;
            const e = pickEmail(extractEmails(sub.text), new URL(sub.url).hostname.replace(/^www\./, ""));
            if (e) return { email: e, source: sub.url, note: "found on the creator's own site via link-in-bio" };
          }
        }
      }
    }
  }
  return { email: null, source: null, note: "bio link readable but no email found" };
}

/** YouTube: the channel description is public text the creator wrote. */
async function verifyChannel(bio: string, channelUrl: string): Promise<Outcome> {
  const inBio = pickEmail(extractEmails(bio));
  if (inBio) return { email: inBio, source: channelUrl, note: "found in the channel description" };
  const sites = followable(extractUrls(bio));
  if (!sites.length) return { email: null, source: null, note: "channel description has no email or website" };
  return await readSites(sites);
}

async function verifyHandle(handle: string): Promise<Outcome> {
  const profileUrl = `https://www.tiktok.com/@${encodeURIComponent(handle)}`;
  const profile = await fetchPage(profileUrl);
  if (!profile) return { email: null, source: null, note: "profile page not readable (blocked or not found)" };

  const { present, bio, link } = parseTikTokProfile(profile.text);
  if (!present) return { email: null, source: null, note: "TikTok returned no profile data to automated readers; needs manual lookup or an official API" };
  const inBio = pickEmail(extractEmails(bio));
  if (inBio) return { email: inBio, source: profileUrl, note: "found in TikTok bio" };
  if (!link) return { email: null, source: null, note: "profile readable but no email or bio link" };

  return await readSites(followable(extractLinks(`<a href="${link}">`, profileUrl)));
}

async function main() {
  const { data: queue, error } = await supabase
    .from("influencer_prospects")
    .select("id, handle, platform, bio, channel_url")
    .in("platform", ["youtube", "tiktok"])
    .eq("email_status", "unverified")
    .order("verify_attempted_at", { ascending: true, nullsFirst: true })
    .limit(BATCH);
  if (error) throw error;

  const stats = { checked: 0, verified: 0, not_found: 0, drafts_updated: 0, failures: [] as string[] };
  for (const p of queue || []) {
    const out = p.platform === "youtube" ? await verifyChannel(p.bio || "", p.channel_url || "") : await verifyHandle(p.handle);
    stats.checked++;
    const now = new Date().toISOString();
    const patch = out.email
      ? { email: out.email, email_status: "verified", email_source: out.source, email_verified_at: now, verify_attempted_at: now, verify_note: out.note }
      : { email_status: "not_found", verify_attempted_at: now, verify_note: out.note };
    const { error: upErr } = await supabase.from("influencer_prospects").update(patch).eq("id", p.id);
    if (upErr) { stats.failures.push(`${p.handle}: ${upErr.message}`); continue; }
    if (out.email) {
      stats.verified++;
      const { data: d, error: dErr } = await supabase
        .from("email_drafts").update({ recipient_email: out.email })
        .eq("recipient_platform", p.platform).eq("recipient_name", p.handle)
        .in("status", ["pending_review", "blocked_unverified"]).select("id");
      if (dErr) stats.failures.push(`${p.handle} drafts: ${dErr.message}`); else stats.drafts_updated += d?.length || 0;
    } else {
      stats.not_found++;
    }
    await new Promise((r) => setTimeout(r, 1500));
  }

  await supabase.from("agent_logs").insert({
    agent_type: "contact_verifier", action: "verify_prospect_contacts",
    status: stats.failures.length ? "error" : "success",
    details: { checked: stats.checked, verified: stats.verified, not_found: stats.not_found, drafts_updated: stats.drafts_updated },
    error_message: stats.failures.length ? stats.failures.join(" | ").slice(0, 2000) : null,
  });
  return { status: stats.failures.length ? "error" : "success", ...stats };
}

Deno.serve(async (req) => {
  const denied = requireServiceRole(req);
  if (denied) return denied;
  try {
    const result = await main();
    return new Response(JSON.stringify(result), { headers: { "Content-Type": "application/json" }, status: result.status === "success" ? 200 : 500 });
  } catch (e) {
    return new Response(JSON.stringify({ status: "error", error: String(e) }), { headers: { "Content-Type": "application/json" }, status: 500 });
  }
});
