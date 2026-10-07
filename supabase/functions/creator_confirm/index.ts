import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { sha256Hex } from "../_shared/http.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") || "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "",
);

const PAGE = "https://outlayapp.net/creators.html";
const MAX_AGE_MS = 7 * 24 * 3600_000;

const redirect = (ok: boolean) =>
  new Response(null, { status: 302, headers: { Location: `${PAGE}?confirmed=${ok ? 1 : 0}` } });

Deno.serve(async (req) => {
  const token = new URL(req.url).searchParams.get("t") || "";
  if (!/^[0-9a-f]{64}$/.test(token)) return redirect(false);

  const hash = await sha256Hex(token);
  const { data: app } = await supabase
    .from("creator_applications")
    .select("id, name, status, confirm_sent_at")
    .eq("confirm_token_hash", hash)
    .maybeSingle();

  if (!app || app.status !== "pending_confirmation") return redirect(false);
  if (!app.confirm_sent_at || Date.now() - new Date(app.confirm_sent_at).getTime() > MAX_AGE_MS) return redirect(false);

  const { error } = await supabase
    .from("creator_applications")
    .update({ status: "confirmed", confirmed_at: new Date().toISOString(), confirm_token_hash: null })
    .eq("id", app.id)
    .eq("status", "pending_confirmation");
  if (error) return redirect(false);

  // Tell the admins in their in-app inbox.
  const { data: admins } = await supabase.from("app_admins").select("user_id");
  if (admins?.length) {
    await supabase.from("inbox_notifications").insert(
      admins.map((a: { user_id: string }) => ({
        user_id: a.user_id,
        type: "creator_application",
        title: "New creator application",
        body: `${app.name} confirmed their email and is waiting for review.`,
        data: { application_id: app.id },
      })),
    );
  }
  return redirect(true);
});
