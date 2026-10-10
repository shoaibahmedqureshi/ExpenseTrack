import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { requireServiceRole } from "../_shared/service_auth.ts";
import { parseModelJson } from "../_shared/agent_run.ts";
import { extractEmails, pickEmail } from "../_shared/contact_finder.ts";
import { fetchPage } from "../_shared/safe_fetch.ts";
import { collectSearchUrls, filterCandidates, offerLine, pageSummary, pitchPages, PRODUCTS, siteOf } from "../_shared/blog_outreach.ts";

const supabase = createClient(Deno.env.get("SUPABASE_URL") || "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "");
const MODEL = Deno.env.get("BLOG_AGENT_MODEL") || "claude-haiku-4-5-20251001";
const TOPICS = ["personal finance and budgeting", "photography and photo editing", "productivity apps and tools"];

async function claudeRequest(body: Record<string, unknown>) {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "x-api-key": Deno.env.get("CLAUDE_API_KEY") || "", "anthropic-version": "2023-06-01", "content-type": "application/json" },
    body: JSON.stringify({ model: MODEL, ...body }),
    signal: AbortSignal.timeout(120000),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`Claude: ${json?.error?.message || res.status}`);
  return json;
}

/** Finds real blogs that accept guest posts. Only URLs the search tool returned are kept. */
async function discover(topics: string[]) {
  const stats = { found: 0, saved: 0, already_known: 0, failures: [] as string[], notes: [] as string[] };
  for (const topic of topics.slice(0, 3)) {
    const r = await claudeRequest({
      max_tokens: 2000,
      tools: [{ type: "web_search_20250305", name: "web_search", max_uses: 4 }],
      messages: [{
        role: "user",
        content: `Use web search to find 6 active blogs or publications about ${topic} that accept guest posts (look for "write for us" or contributor guidelines pages). Prefer small to mid-sized independent sites. Reply with ONLY a JSON array of {"blog_name","url","topic","guidelines_url"}, where url is the blog's home page or guest-post page exactly as returned by search.`,
      }],
    });
    const allowed = collectSearchUrls(r.content);
    const text = (r.content as Array<{ type: string; text?: string }>).filter((b) => b.type === "text").map((b) => b.text).join("\n");
    let cands: ReturnType<typeof filterCandidates> = [];
    try { cands = filterCandidates(parseModelJson(text), allowed); } catch (e) { stats.failures.push(`${topic}: ${String(e)}`); continue; }
    if (!cands.length) {
      const types = (r.content as Array<{ type: string }>).map((b) => b.type).join(",");
      stats.notes.push(`${topic}: no usable blogs (blocks: ${types}; search urls: ${allowed.size}; reply: ${text.slice(0, 200).replace(/\s+/g, " ")})`);
    }
    stats.found += cands.length;
    for (const c of cands) {
      const site = siteOf(c.url!);
      const { data: known } = await supabase.from("link_opportunities").select("id").eq("domain", site).limit(1);
      if (known?.length) { stats.already_known++; continue; }
      const { error } = await supabase.from("link_opportunities").insert({
        domain: site, url: c.url, blog_name: c.blog_name?.slice(0, 200), topic: c.topic?.slice(0, 200) || topic,
        guidelines_url: c.guidelines_url, source_query: topic, outreach_status: "discovered", email_status: "unverified",
      });
      if (error) stats.failures.push(`${site}: ${error.message}`); else stats.saved++;
    }
  }
  return stats;
}

/** Reads the blog's own pages for a published contact address. */
async function verify(limit = 10) {
  const stats = { checked: 0, verified: 0, not_found: 0, failures: [] as string[] };
  const { data: queue } = await supabase.from("link_opportunities").select("id, url, guidelines_url, domain")
    .eq("email_status", "unverified").order("verify_attempted_at", { ascending: true, nullsFirst: true }).limit(limit);
  for (const o of queue || []) {
    stats.checked++;
    let email: string | null = null, source: string | null = null, summary = "";
    for (const page of pitchPages(o.url, o.guidelines_url)) {
      const p = await fetchPage(page);
      if (!p) continue;
      if (!summary && page === o.url) summary = pageSummary(p.text);
      const found = pickEmail(extractEmails(p.text), siteOf(o.url));
      if (found) { email = found; source = p.url; break; }
    }
    const now = new Date().toISOString();
    const patch = email
      ? { email, email_status: "verified", email_source: source, email_verified_at: now, verify_attempted_at: now, verify_note: "found on the blog's own site", outreach_status: "verified", page_summary: summary || null }
      : { email_status: "not_found", verify_attempted_at: now, verify_note: "no email on the blog's contact, about or guest-post pages", page_summary: summary || null };
    const { error } = await supabase.from("link_opportunities").update(patch).eq("id", o.id);
    if (error) stats.failures.push(`${o.domain}: ${error.message}`); else if (email) stats.verified++; else stats.not_found++;
    await new Promise((r) => setTimeout(r, 1000));
  }
  return stats;
}

/** Drafts one pitch per verified blog. Drafts are never sent from here. */
async function draft(limit = 5) {
  const stats = { drafted: 0, failures: [] as string[] };
  const { data: ops } = await supabase.from("link_opportunities")
    .select("id, url, blog_name, topic, page_summary, guidelines_url").eq("email_status", "verified").eq("outreach_status", "verified").limit(limit);
  for (const o of ops || []) {
    try {
      const r = await claudeRequest({
        max_tokens: 900,
        messages: [{
          role: "user",
          content: `Write a short guest-post pitch email to the editor of ${o.blog_name || o.url}.
Facts you may use about the blog (nothing else): ${o.page_summary || "none available"}; topic: ${o.topic || "unknown"}.
Do NOT claim to have read, followed or liked any specific article. Do not invent statistics or testimonials.
Offer: ${offerLine()}, for the editor and team to use freely whether or not the post runs.
Propose 3 post ideas that suit the blog's topic and honestly relate to ${PRODUCTS.map((p) => p.name).join(" / ")}, written to be useful to readers rather than an ad.
Under 150 words. Plain text, no markdown, sign off as "The Outlay team".
Reply with ONLY JSON: {"subject": string, "body": string, "post_ideas": string[]}`,
        }],
      });
      const text = (r.content as Array<{ type: string; text?: string }>).filter((b) => b.type === "text").map((b) => b.text).join("\n");
      const p = parseModelJson<{ subject: string; body: string; post_ideas: string[] }>(text);
      if (!p.subject || !p.body) throw new Error("empty draft");
      const { error } = await supabase.from("guest_post_pitches").insert({
        link_opportunity_id: o.id, subject: p.subject.slice(0, 200), title: (p.post_ideas?.[0] || "").slice(0, 200),
        content_brief: (p.post_ideas || []).join("\n"), pitch_text: p.body, status: "draft", products: PRODUCTS.map((x) => x.name),
      });
      if (error) throw new Error(error.message);
      await supabase.from("link_opportunities").update({ outreach_status: "pitch_drafted", subscription_offered: "all_products_1y" }).eq("id", o.id);
      stats.drafted++;
    } catch (e) { stats.failures.push(`${o.url}: ${String(e)}`); }
  }
  return stats;
}

Deno.serve(async (req) => {
  const denied = requireServiceRole(req);
  if (denied) return denied;
  const body = await req.json().catch(() => ({}));
  const action = String(body.action || "");
  try {
    const run = action === "discover" ? () => discover(Array.isArray(body.topics) && body.topics.length ? body.topics.map(String) : TOPICS)
      : action === "verify" ? () => verify() : action === "draft" ? () => draft() : null;
    if (!run) return new Response(JSON.stringify({ status: "error", error: 'action must be "discover", "verify" or "draft"' }), { status: 400, headers: { "Content-Type": "application/json" } });
    const stats = await run();
    const failed = stats.failures.length > 0;
    const { failures, ...counts } = stats as typeof stats & { failures: string[] };
    await supabase.from("agent_logs").insert({ agent_type: "blog_outreach", action, status: failed ? "error" : "success", details: counts, error_message: failed ? failures.join(" | ").slice(0, 2000) : null });
    return new Response(JSON.stringify({ status: failed ? "error" : "success", ...stats }), { status: failed ? 500 : 200, headers: { "Content-Type": "application/json" } });
  } catch (e) {
    await supabase.from("agent_logs").insert({ agent_type: "blog_outreach", action, status: "error", error_message: String(e).slice(0, 2000) });
    return new Response(JSON.stringify({ status: "error", error: String(e) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
