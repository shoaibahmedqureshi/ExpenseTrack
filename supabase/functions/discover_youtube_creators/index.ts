import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { requireServiceRole } from "../_shared/service_auth.ts";

const supabase = createClient(Deno.env.get("SUPABASE_URL") || "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "");
const API = "https://www.googleapis.com/youtube/v3";

const DEFAULT_QUERIES = ["photo editing tutorial", "travel photography tips", "photo collage app"];
const MIN_SUBS = 3_000;
const MAX_SUBS = 500_000;
const PER_QUERY = 10; // search.list costs 100 quota units per call; the daily free quota is 10,000

async function yt(path: string, params: Record<string, string>, key: string) {
  const url = new URL(`${API}/${path}`);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
  url.searchParams.set("key", key);
  const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
  const body = await res.json();
  if (!res.ok) throw new Error(`YouTube ${path}: ${body?.error?.message || res.status}`);
  return body;
}

async function main(queries: string[], niche: string) {
  const key = Deno.env.get("YOUTUBE_API_KEY") || "";
  if (!key) return { status: "error", error: "YOUTUBE_API_KEY is not set" };

  const ids = new Set<string>();
  for (const q of queries.slice(0, 3)) {
    const r = await yt("search", { part: "snippet", type: "channel", q, maxResults: String(PER_QUERY) }, key);
    for (const it of r.items || []) if (it.snippet?.channelId || it.id?.channelId) ids.add(it.snippet?.channelId || it.id.channelId);
  }
  if (!ids.size) return { status: "success", found: 0, saved: 0 };

  const details = await yt("channels", { part: "snippet,statistics", id: [...ids].join(",") }, key);
  const stats = { found: ids.size, saved: 0, skipped_size: 0, already_known: 0, failures: [] as string[] };

  for (const ch of details.items || []) {
    const subs = Number(ch.statistics?.subscriberCount || 0);
    if (ch.statistics?.hiddenSubscriberCount || subs < MIN_SUBS || subs > MAX_SUBS) { stats.skipped_size++; continue; }
    const handle = String(ch.snippet?.customUrl || ch.id).replace(/^@/, "");
    const { data: known } = await supabase.from("influencer_prospects").select("id").eq("platform", "youtube").eq("handle", handle).maybeSingle();
    if (known) { stats.already_known++; continue; }
    const { error } = await supabase.from("influencer_prospects").insert({
      platform: "youtube",
      handle,
      follower_count: subs,
      niche,
      contact_method: "email",
      channel_url: `https://www.youtube.com/channel/${ch.id}`,
      bio: String(ch.snippet?.description || "").slice(0, 5000),
      email_status: "unverified",
    });
    if (error) stats.failures.push(`${handle}: ${error.message}`); else stats.saved++;
  }

  await supabase.from("agent_logs").insert({
    agent_type: "youtube_discovery", action: "discover_youtube_creators",
    status: stats.failures.length ? "error" : "success",
    details: { found: stats.found, saved: stats.saved, skipped_size: stats.skipped_size, already_known: stats.already_known },
    error_message: stats.failures.length ? stats.failures.join(" | ").slice(0, 2000) : null,
  });
  return { status: stats.failures.length ? "error" : "success", ...stats };
}

Deno.serve(async (req) => {
  const denied = requireServiceRole(req);
  if (denied) return denied;
  try {
    const body = await req.json().catch(() => ({}));
    const queries = Array.isArray(body.queries) && body.queries.length ? body.queries.map(String) : DEFAULT_QUERIES;
    const result = await main(queries, String(body.niche || "photography"));
    return new Response(JSON.stringify(result), { headers: { "Content-Type": "application/json" }, status: result.status === "success" ? 200 : 500 });
  } catch (e) {
    return new Response(JSON.stringify({ status: "error", error: String(e) }), { headers: { "Content-Type": "application/json" }, status: 500 });
  }
});
