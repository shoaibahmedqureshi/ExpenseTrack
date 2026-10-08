import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { verifyUnsubscribeToken } from "../_shared/unsubscribe.ts";

// "Stop emailing me" for Outlay group invitations. Works on a plain GET (the link in the email) and on a POST
// (one-click unsubscribe from the mail app). It records the address and nothing else; it is safe to repeat.
// Supabase serves function responses as plain text, so the confirmation is plain text too.

const text = (body: string, status = 200) =>
  new Response(body, { status, headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" } });

Deno.serve(async (req) => {
  if (req.method !== "GET" && req.method !== "POST") return text("Method not allowed", 405);

  let token = new URL(req.url).searchParams.get("t") || "";
  if (!token && req.method === "POST") {
    try {
      token = String((await req.formData()).get("t") || "");
    } catch (_) { /* no form body */ }
  }

  const email = await verifyUnsubscribeToken(Deno.env.get("UNSUBSCRIBE_SECRET") || "", token);
  if (!email) return text("This link is not valid. If you still want to stop the emails, write to contact@outlayapp.net.", 400);

  const admin = createClient(Deno.env.get("SUPABASE_URL") || "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "");
  const { error } = await admin
    .from("email_suppressions")
    .upsert({ email, scope: "group_invite" }, { onConflict: "email,scope", ignoreDuplicates: true });
  if (error) {
    console.error("email_optout failed:", error.message);
    return text("Something went wrong. Please try the link again in a minute.", 500);
  }
  return text(`Done. Outlay will not email ${email} about group invitations again.`);
});
