import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { getEmailConfig, sendEmail } from "../_shared/email_service.ts";
import { corsHeaders, json } from "../_shared/http.ts";
import { buildInviteEmail } from "../_shared/group_invite_email.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders(req) });
  if (req.method !== "POST") return json(req, { error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL") || "";
  const auth = req.headers.get("Authorization") || "";
  const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY") || "", { global: { headers: { Authorization: auth } } });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData?.user) return json(req, { error: "Please sign in" }, 401);

  let body: { invitation_id?: unknown };
  try {
    body = await req.json();
  } catch (_) {
    return json(req, { error: "Invalid request" }, 400);
  }
  const invitationId = Number(body.invitation_id);
  if (!Number.isInteger(invitationId) || invitationId <= 0) return json(req, { error: "Invalid invitation" }, 400);

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "");
  const { data: claim, error: claimErr } = await admin.rpc("claim_group_invite_email", {
    p_invitation_id: invitationId,
    p_user: userData.user.id,
  });
  if (claimErr) {
    console.error("claim_group_invite_email failed:", claimErr.message);
    return json(req, { sent: false, reason: "error" }, 500);
  }
  if (!claim?.ok) return json(req, { sent: false, reason: claim?.reason ?? "error" });

  const mail = buildInviteEmail(claim.inviter_name, claim.group_name, claim.email, new Date(claim.expires_at));
  const result = await sendEmail({
    to: claim.email,
    subject: mail.subject,
    text: mail.text,
    categories: ["group-invite"],
    transactional: true,
  });
  if (!result.success) {
    console.error("group invite email failed:", result.error);
    await admin.rpc("release_group_invite_email", { p_invitation_id: invitationId });
    return json(req, { sent: false, reason: "send_failed" }, 502);
  }
  // In sandbox mode SendGrid validates the message but delivers nothing.
  return json(req, { sent: true, delivered: !getEmailConfig().sandbox });
});
