import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { sendEmail } from "../_shared/email_service.ts";
import { corsHeaders, json, randomToken, sha256Hex } from "../_shared/http.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") || "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "",
);

const PLATFORMS = ["tiktok", "youtube", "instagram", "x", "other"];
const BANDS = ["under_1k", "1k_10k", "10k_50k", "50k_250k", "over_250k"];
const EMAIL_RE = /^[^\s@<>"',;]+@[^\s@<>"',;]+\.[A-Za-z]{2,}$/;
const MAX_BODY = 8000;
const PER_IP_HOUR = 6;
const PER_EMAIL_HOUR = 3;
const RESEND_AFTER_MS = 10 * 60 * 1000;

const str = (v: unknown, max: number) => (typeof v === "string" ? v.trim().slice(0, max) : "");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders(req) });
  if (req.method !== "POST") return json(req, { error: "Method not allowed" }, 405);

  const raw = await req.text();
  if (raw.length > MAX_BODY) return json(req, { error: "Request too large" }, 413);
  let b: Record<string, unknown>;
  try {
    b = JSON.parse(raw);
  } catch {
    return json(req, { error: "Invalid JSON" }, 400);
  }

  // Bot traps: a hidden field real people never fill, and a form that was open for under 3 seconds.
  if (str(b.website, 200) !== "" || (typeof b.elapsed_ms === "number" && b.elapsed_ms < 3000)) {
    return json(req, { ok: true }); // pretend success, store nothing
  }

  const name = str(b.name, 100);
  const email = str(b.email, 200).toLowerCase();
  const platform = str(b.platform, 20);
  const handle = str(b.handle, 100);
  const profileUrl = str(b.profile_url, 300);
  const band = str(b.audience_band, 20);
  const niche = str(b.niche, 120);
  const about = str(b.about, 1000);
  const country = str(b.country, 60);

  const errors: Record<string, string> = {};
  if (!name) errors.name = "Please enter your name";
  if (!EMAIL_RE.test(email)) errors.email = "Please enter a valid email address";
  if (!PLATFORMS.includes(platform)) errors.platform = "Choose a platform";
  if (!handle) errors.handle = "Please enter your handle or channel name";
  if (profileUrl && !/^https?:\/\/\S+$/i.test(profileUrl)) errors.profile_url = "Enter a full link starting with https://";
  if (!BANDS.includes(band)) errors.audience_band = "Choose your audience size";
  if (niche.length < 2) errors.niche = "Tell us what you create content about";
  if (b.consent !== true) errors.consent = "Please agree so we can email you about the program";
  if (Object.keys(errors).length) return json(req, { error: "Please fix the highlighted fields", errors }, 400);

  // Throttle by hashed IP and hashed email (no raw IPs stored).
  const salt = (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "").slice(-16);
  const ip = (req.headers.get("x-forwarded-for") || "unknown").split(",")[0].trim();
  const ipHash = await sha256Hex(`${salt}|${ip}`);
  const emailHash = await sha256Hex(`${salt}|${email}`);
  const since = new Date(Date.now() - 3600_000).toISOString();
  const [{ count: ipCount }, { count: emCount }] = await Promise.all([
    supabase.from("creator_apply_attempts").select("id", { count: "exact", head: true }).eq("ip_hash", ipHash).gte("created_at", since),
    supabase.from("creator_apply_attempts").select("id", { count: "exact", head: true }).eq("email_hash", emailHash).gte("created_at", since),
  ]);
  if ((ipCount ?? 0) >= PER_IP_HOUR || (emCount ?? 0) >= PER_EMAIL_HOUR) {
    return json(req, { error: "Too many attempts. Please try again in an hour." }, 429);
  }
  await supabase.from("creator_apply_attempts").insert({ ip_hash: ipHash, email_hash: emailHash });

  // Same response whether or not the address already applied, so the form can't be used to probe who applied.
  const accepted = { ok: true, message: "Check your inbox to confirm your email and finish applying." };

  const { data: existing } = await supabase
    .from("creator_applications")
    .select("id, status, confirm_sent_at")
    .eq("email", email)
    .maybeSingle();

  const token = randomToken();
  const tokenHash = await sha256Hex(token);
  let applicantId: number | null = null;

  if (existing) {
    const stale = !existing.confirm_sent_at || Date.now() - new Date(existing.confirm_sent_at).getTime() > RESEND_AFTER_MS;
    if (existing.status !== "pending_confirmation" || !stale) return json(req, accepted);
    applicantId = existing.id;
    await supabase.from("creator_applications").update({ confirm_token_hash: tokenHash }).eq("id", existing.id);
  } else {
    const { data, error } = await supabase
      .from("creator_applications")
      .insert({
        name, email, platform, handle,
        profile_url: profileUrl || null,
        audience_band: band, niche,
        about: about || null,
        country: country || null,
        consent_at: new Date().toISOString(),
        source: str(b.source, 80) || null,
        confirm_token_hash: tokenHash,
      })
      .select("id")
      .single();
    if (error) {
      console.error("creator_apply insert failed:", error.message);
      return json(req, { error: "Something went wrong. Please try again." }, 500);
    }
    applicantId = data.id;
  }

  const link = `${Deno.env.get("SUPABASE_URL")}/functions/v1/creator_confirm?t=${token}`;
  const mail = await sendEmail({
    to: email,
    subject: "Confirm your Outlay Creator Program application",
    text:
      `Hi ${name.split(" ")[0] || "there"},\n\n` +
      "Thanks for applying to the Outlay Creator Program. Please confirm your email address to finish your application:\n\n" +
      `${link}\n\n` +
      "This link works for 7 days. If you didn't apply, you can ignore this message and nothing will happen.\n\n" +
      "The Outlay team",
    categories: ["creator-program", "confirmation"],
    transactional: true,
  });
  if (!mail.success) {
    console.error("creator_apply confirmation email failed:", mail.error);
    return json(req, { error: "We couldn't send the confirmation email. Please try again shortly." }, 502);
  }
  await supabase.from("creator_applications").update({ confirm_sent_at: new Date().toISOString() }).eq("id", applicantId);
  return json(req, accepted);
});
