/**
 * Agent email via the SendGrid v3 Web API.
 *
 * Safety model (all controlled by Edge Function secrets):
 *  - AGENT_EMAIL_ENABLED must be exactly "true" or nothing is sent at all.
 *  - AGENT_TEST_RECIPIENT, when set, redirects EVERY message to that one address
 *    (subject prefixed with the intended recipient) so the pipeline can be proven
 *    end to end without contacting anyone else.
 *  - SENDGRID_SANDBOX="true" makes SendGrid validate the request without delivering.
 *  - AGENT_BCC, when set, receives a hidden copy of every message (a stand-in for a Sent folder).
 *  - Addresses that are obviously fabricated (handle@tiktok.com etc.) are refused.
 */

export interface SendResult {
  success: boolean;
  error?: string;
  skipped?: boolean;
  messageId?: string;
  redirectedTo?: string;
}

export interface SendArgs {
  to: string;
  subject: string;
  text: string;
  categories?: string[];
}

export function getEmailConfig() {
  const fromEmail = Deno.env.get("AGENT_EMAIL_FROM") || "";
  return {
    apiKey: Deno.env.get("SENDGRID_API_KEY") || "",
    fromEmail,
    fromName: Deno.env.get("AGENT_EMAIL_FROM_NAME") || "Outlay",
    replyTo: Deno.env.get("AGENT_REPLY_TO") || fromEmail,
    footer: Deno.env.get("AGENT_EMAIL_FOOTER") || "",
    enabled: Deno.env.get("AGENT_EMAIL_ENABLED") === "true",
    sandbox: Deno.env.get("SENDGRID_SANDBOX") === "true",
    testRecipient: (Deno.env.get("AGENT_TEST_RECIPIENT") || "").trim(),
    bcc: (Deno.env.get("AGENT_BCC") || "").trim(),
  };
}

const EMAIL_RE = /^[^\s@<>"',;]+@[^\s@<>"',;]+\.[A-Za-z]{2,}$/;
const SOCIAL_HOSTS = /@(tiktok|instagram|youtube|twitter|x|facebook|linkedin)\.com$/i;

export function isPlausibleRecipient(email: string): boolean {
  return EMAIL_RE.test(email) && !SOCIAL_HOSTS.test(email);
}

function clean(s: string): string {
  // No header injection through subject/name fields.
  return s.replace(/[\r\n]+/g, " ").trim();
}

export async function sendEmail(args: SendArgs): Promise<SendResult> {
  const cfg = getEmailConfig();

  if (!cfg.enabled) {
    return { success: false, skipped: true, error: "Agent email is switched off (AGENT_EMAIL_ENABLED is not \"true\")" };
  }
  if (!cfg.apiKey) return { success: false, error: "SENDGRID_API_KEY is not set" };
  if (!cfg.fromEmail || !EMAIL_RE.test(cfg.fromEmail)) return { success: false, error: "AGENT_EMAIL_FROM is not a valid address" };

  const intended = args.to.trim();
  if (!isPlausibleRecipient(intended)) {
    return { success: false, skipped: true, error: `Refusing to send to an invalid or fabricated address: ${intended}` };
  }

  let to = intended;
  let subject = clean(args.subject);
  let redirectedTo: string | undefined;
  if (cfg.testRecipient) {
    if (!EMAIL_RE.test(cfg.testRecipient)) return { success: false, error: "AGENT_TEST_RECIPIENT is not a valid address" };
    to = cfg.testRecipient;
    redirectedTo = to;
    subject = `[TEST for ${intended}] ${subject}`;
  }

  // SendGrid rejects a personalization where the same address appears twice.
  const bcc = cfg.bcc && EMAIL_RE.test(cfg.bcc) && cfg.bcc.toLowerCase() !== to.toLowerCase() ? cfg.bcc : "";

  const body = cfg.footer ? `${args.text}\n\n--\n${cfg.footer}` : args.text;
  const payload = {
    personalizations: [{ to: [{ email: to }], ...(bcc ? { bcc: [{ email: bcc }] } : {}) }],
    from: { email: cfg.fromEmail, name: clean(cfg.fromName) },
    reply_to: { email: cfg.replyTo },
    subject,
    content: [{ type: "text/plain", value: body }],
    categories: (args.categories ?? ["agent"]).slice(0, 10),
    headers: { "List-Unsubscribe": `<mailto:${cfg.replyTo}?subject=unsubscribe>` },
    mail_settings: { sandbox_mode: { enable: cfg.sandbox } },
  };

  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 15000);
  try {
    const res = await fetch("https://api.sendgrid.com/v3/mail/send", {
      method: "POST",
      headers: { Authorization: `Bearer ${cfg.apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: ctrl.signal,
    });
    if (res.status === 202 || (cfg.sandbox && res.status === 200)) {
      return { success: true, messageId: res.headers.get("x-message-id") ?? undefined, redirectedTo };
    }
    let detail = "";
    try {
      const j = await res.json();
      detail = (j.errors ?? []).map((e: { message: string }) => e.message).join("; ");
    } catch (_) { /* no body */ }
    return { success: false, error: `SendGrid ${res.status}${detail ? `: ${detail}` : ""}` };
  } catch (e) {
    return { success: false, error: e instanceof Error ? e.message : String(e) };
  } finally {
    clearTimeout(timer);
  }
}
