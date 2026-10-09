import { getEmailConfig, sendEmail } from "../_shared/email_service.ts";
import { requireServiceRole } from "../_shared/service_auth.ts";

// Sends ONE test message, only to AGENT_TEST_RECIPIENT, never to anyone else.
// Use it to prove SendGrid is wired up before the agents are allowed to send.
Deno.serve(async (req) => {
  const denied = requireServiceRole(req);
  if (denied) return denied;
  const cfg = getEmailConfig();
  if (!cfg.testRecipient) {
    return Response.json(
      { ok: false, error: "Set AGENT_TEST_RECIPIENT to your own address first." },
      { status: 400 },
    );
  }
  const result = await sendEmail({
    to: cfg.testRecipient,
    subject: "Outlay agent email test",
    text:
      "This is a test from the Outlay agent email setup.\n\n" +
      `Sandbox mode: ${cfg.sandbox ? "ON (not delivered)" : "off"}\n` +
      `Sent via SendGrid at ${new Date().toISOString()}`,
    categories: ["agent", "test"],
  });
  return Response.json(
    { ok: result.success, ...result, from: cfg.fromEmail, sandbox: cfg.sandbox, enabled: cfg.enabled },
    { status: result.success ? 200 : 502 },
  );
});
