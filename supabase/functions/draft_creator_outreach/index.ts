import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { requireServiceRole } from "../_shared/service_auth.ts";
import { parseModelJson } from "../_shared/agent_run.ts";
import { buildCreatorPitch, safeOpening } from "../_shared/creator_pitch.ts";

const supabase = createClient(Deno.env.get("SUPABASE_URL") || "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "");
const MODEL = Deno.env.get("BLOG_AGENT_MODEL") || "claude-haiku-4-5-20251001";
const LIMIT = 8;

async function openingLine(handle: string, niche: string, bio: string): Promise<string | undefined> {
  if (!bio.trim()) return undefined;
  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": Deno.env.get("CLAUDE_API_KEY") || "", "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({
        model: MODEL, max_tokens: 200,
        messages: [{ role: "user", content: `Below is the public description of the YouTube channel "${handle}" (niche: ${niche}). Write ONE friendly sentence (under 30 words) saying what the channel is about, using only what the description says. Do not say you watched, followed or liked anything. Reply with ONLY JSON: {"opening": string}.\n\nDescription:\n${bio.slice(0, 1200)}` }],
      }),
      signal: AbortSignal.timeout(30000),
    });
    const j = await res.json();
    if (!res.ok) return undefined;
    const text = (j.content as Array<{ type: string; text?: string }>).filter((b) => b.type === "text").map((b) => b.text).join("");
    return parseModelJson<{ opening?: string }>(text).opening;
  } catch { return undefined; }
}

async function main() {
  const stats = { drafted: 0, neutral_opening: 0, failures: [] as string[] };
  const { data: prospects, error } = await supabase.from("influencer_prospects")
    .select("handle, platform, niche, follower_count, bio, email, channel_url")
    .eq("platform", "youtube").eq("email_status", "verified").not("email", "is", null).limit(50);
  if (error) throw error;

  let done = 0;
  for (const p of prospects || []) {
    if (done >= LIMIT) break;
    const { data: existing } = await supabase.from("email_drafts").select("id").eq("recipient_platform", "youtube").eq("recipient_name", p.handle).limit(1);
    if (existing?.length) continue;
    const facts = { handle: p.handle, niche: p.niche || "your topic", subscribers: p.follower_count || 0, bio: p.bio || "" };
    const modelLine = await openingLine(p.handle, facts.niche, facts.bio);
    const opening = safeOpening(modelLine, facts);
    if (opening !== modelLine) stats.neutral_opening++;
    const { subject, body } = buildCreatorPitch(facts, opening);
    const { error: insErr } = await supabase.from("email_drafts").insert({
      agent_type: "influencer", recipient_name: p.handle, recipient_email: p.email, recipient_platform: "youtube",
      recipient_url: p.channel_url, subject, body, status: "pending_review",
      metadata: { product: "outlay_stitchify", source: "youtube", follower_count: p.follower_count, niche: p.niche, offer: "free_1y_all_products + creator_programme" },
    });
    if (insErr) stats.failures.push(`${p.handle}: ${insErr.message}`); else { stats.drafted++; done++; }
  }

  await supabase.from("agent_logs").insert({
    agent_type: "creator_drafts", action: "draft_creator_outreach", status: stats.failures.length ? "error" : "success",
    details: { drafted: stats.drafted, neutral_opening: stats.neutral_opening },
    error_message: stats.failures.length ? stats.failures.join(" | ").slice(0, 2000) : null,
  });
  return { status: stats.failures.length ? "error" : "success", ...stats };
}

Deno.serve(async (req) => {
  const denied = requireServiceRole(req);
  if (denied) return denied;
  try {
    const r = await main();
    return new Response(JSON.stringify(r), { headers: { "Content-Type": "application/json" }, status: r.status === "success" ? 200 : 500 });
  } catch (e) {
    return new Response(JSON.stringify({ status: "error", error: String(e) }), { headers: { "Content-Type": "application/json" }, status: 500 });
  }
});
