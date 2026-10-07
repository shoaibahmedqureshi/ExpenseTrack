import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { Anthropic } from "https://esm.sh/@anthropic-ai/sdk@0.24.3";
import { corsHeaders, json } from "../_shared/http.ts";

const claude = new Anthropic({ apiKey: Deno.env.get("CLAUDE_API_KEY") || "" });

const CHANNELS: Record<string, string> = {
  tiktok_invite: "a short TikTok One / Creator Marketplace invitation note (max 400 characters)",
  instagram_dm: "a short Instagram DM (max 500 characters, conversational)",
  youtube_email: "a short email to the creator's public business address (subject line plus 90-150 words)",
  email: "a short email (subject line plus 90-150 words)",
  other: "a short, friendly message (max 600 characters)",
};

// What Outlay can truthfully say. Edit here, not in the model's imagination.
const FACTS = `Outlay is a privacy-first expense tracker for iOS and Android: scan receipts, track spending, budgets, and split costs with family or friends.
Creator program: creators get a personal discount code to share with their audience, and earn a 20% revenue share on subscribers who join with their code, paid once per subscriber.
Do not promise anything beyond this. Do not state follower numbers, view counts or specific videos unless they appear in the creator info below.`;

const str = (v: unknown, max: number) => (typeof v === "string" ? v.trim().slice(0, max) : "");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders(req) });
  if (req.method !== "POST") return json(req, { error: "Method not allowed" }, 405);

  // Only app admins, checked with the caller's own token.
  const auth = req.headers.get("Authorization") || "";
  const userClient = createClient(Deno.env.get("SUPABASE_URL") || "", Deno.env.get("SUPABASE_ANON_KEY") || "", {
    global: { headers: { Authorization: auth } },
  });
  const { data: isAdmin, error: adminErr } = await userClient.rpc("is_app_admin");
  if (adminErr || isAdmin !== true) return json(req, { error: "Admins only" }, 403);

  let b: Record<string, unknown>;
  try {
    b = await req.json();
  } catch {
    return json(req, { error: "Invalid JSON" }, 400);
  }
  const name = str(b.creator_name, 120);
  const platform = str(b.platform, 20);
  const channel = str(b.channel, 30);
  const handle = str(b.handle, 100);
  const url = str(b.profile_url, 300);
  const info = str(b.creator_info, 3000);
  if (!name) return json(req, { error: "creator_name is required" }, 400);
  if (!(channel in CHANNELS)) return json(req, { error: "Unknown channel" }, 400);

  const prompt = `You help write respectful, honest outreach for the Outlay Creator Program.

FACTS ABOUT OUTLAY (the only claims you may make):
${FACTS}

CREATOR (all you know about them):
Name: ${name}
Platform: ${platform || "unknown"}  Handle: ${handle || "unknown"}  Profile: ${url || "unknown"}
Pasted info (bio / recent video titles / notes written by a human):
"""${info || "(nothing provided)"}"""

TASK
1. Decide the creator's niche ONLY from the pasted info. If the info is empty or too thin, set niche to null and say so.
2. Say whether they plausibly fit an expense-tracking / personal-finance / budgeting / money-habits audience, with a short reason that quotes the pasted info as evidence. Never invent details about them.
3. Write ${CHANNELS[channel]}. Plain, warm, specific to the evidence, no hype, no emojis, no "I've been following you" unless the info says so. Mention the discount code and revenue share briefly. Invite a reply; do not pressure.

Reply with ONLY JSON: {"niche": string|null, "fits": true|false|null, "fit_reason": string, "evidence": [string], "subject": string|null, "draft": string}`;

  try {
    const res = await claude.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 900,
      messages: [{ role: "user", content: prompt }],
    });
    const text = res.content.map((c: { type: string; text?: string }) => (c.type === "text" ? c.text : "")).join("");
    const m = text.match(/\{[\s\S]*\}/);
    if (!m) return json(req, { error: "The model returned an unreadable answer. Try again." }, 502);
    const o = JSON.parse(m[0]);
    const evidence = Array.isArray(o.evidence) ? o.evidence.map((e: unknown) => str(e, 300)).filter(Boolean).slice(0, 5) : [];
    const subject = str(o.subject, 120);
    const draft = str(o.draft, 3500);
    return json(req, {
      niche: o.niche ? str(o.niche, 120) : null,
      fits: typeof o.fits === "boolean" ? o.fits : null,
      fit_reason: str(o.fit_reason, 900),
      evidence: evidence.join("\n"),
      draft: subject ? `Subject: ${subject}\n\n${draft}` : draft,
    });
  } catch (e) {
    console.error("outreach_draft failed:", e instanceof Error ? e.message : e);
    return json(req, { error: "Drafting failed. Try again in a moment." }, 502);
  }
});
