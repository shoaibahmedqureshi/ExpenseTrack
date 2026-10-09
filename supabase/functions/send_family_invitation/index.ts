import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { makeUnsubscribeToken } from "../_shared/unsubscribe.ts";

async function sendEmailViaSMTP(
  to: string,
  subject: string,
  htmlBody: string,
  fromEmail: string,
  fromName: string
): Promise<{ success: boolean; error?: string }> {
  const host = Deno.env.get("NAMECHEAP_SMTP_HOST") || "mail.privateemail.com";
  const user = Deno.env.get("NAMECHEAP_SMTP_USER") || "";
  const pass = Deno.env.get("NAMECHEAP_SMTP_PASSWORD") || "";
  if (!user || !pass) return { success: false, error: "SMTP credentials not configured" };

  const enc = new TextEncoder();
  const dec = new TextDecoder();
  let conn: Deno.Conn | undefined;
  try {
    conn = await Deno.connectTls({ hostname: host, port: 465 });
    let buf = "";
    const readReply = async (): Promise<string> => {
      while (true) {
        const lines = buf.split("\r\n");
        // a reply is complete when a line is "NNN text" (space after code)
        for (let i = 0; i < lines.length - 1; i++) {
          if (/^\d{3} /.test(lines[i]) || /^\d{3}$/.test(lines[i])) {
            const reply = lines.slice(0, i + 1).join("\r\n");
            buf = lines.slice(i + 1).join("\r\n");
            return reply;
          }
        }
        const chunk = new Uint8Array(4096);
        const n = await conn!.read(chunk);
        if (n === null) throw new Error("Connection closed by server");
        buf += dec.decode(chunk.subarray(0, n));
      }
    };
    const cmd = async (c: string, expect: string): Promise<string> => {
      await conn!.write(enc.encode(c + "\r\n"));
      const r = await readReply();
      if (!r.startsWith(expect) && !r.includes("\n" + expect)) {
        throw new Error(`SMTP '${c.split(" ")[0]}' failed: ${r}`);
      }
      return r;
    };

    const greeting = await readReply();
    if (!greeting.startsWith("220")) throw new Error(`Bad greeting: ${greeting}`);
    await cmd("EHLO outlayapp.net", "250");
    await cmd("AUTH LOGIN", "334");
    await cmd(btoa(user), "334");
    await cmd(btoa(pass), "235");
    await cmd(`MAIL FROM:<${user}>`, "250");
    await cmd(`RCPT TO:<${to}>`, "250");
    await cmd("DATA", "354");

    const encSubject = `=?UTF-8?B?${btoa(String.fromCharCode(...enc.encode(subject)))}?=`;
    const bodyB64 = btoa(String.fromCharCode(...enc.encode(htmlBody))).replace(/(.{76})/g, "$1\r\n");
    const msg =
      `From: ${fromName} <${fromEmail}>\r\nTo: ${to}\r\nSubject: ${encSubject}\r\n` +
      `MIME-Version: 1.0\r\nContent-Type: text/html; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\n${bodyB64}\r\n.`;
    await cmd(msg, "250");
    await conn.write(enc.encode("QUIT\r\n"));
    return { success: true };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("Error sending email:", message);
    return { success: false, error: message };
  } finally {
    try { conn?.close(); } catch (_) { /* ignore */ }
  }
}

const esc = (v: unknown) =>
  String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));

async function handleFamilyInvitation(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  const jsonRes = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

  try {
    // Who is asking: the signed-in person, checked with their own token (the public anon key is not a person).
    const url = Deno.env.get("SUPABASE_URL") || "";
    const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY") || "", {
      global: { headers: { Authorization: req.headers.get("Authorization") || "" } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) return jsonRes({ error: "Please sign in" }, 401);

    const { familyId, invitationToken } = await req.json();
    if (!familyId || !invitationToken || typeof invitationToken !== "string") {
      return jsonRes({ error: "Missing required fields" }, 400);
    }

    // Only for a real pending invitation this person created. The address and names come from the database,
    // never from the request, so this cannot be used to mail someone arbitrary text.
    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "");
    const { data: claim, error: claimErr } = await admin.rpc("claim_family_invite_email", {
      p_family_id: Number(familyId),
      p_token: invitationToken,
      p_user: userData.user.id,
    });
    if (claimErr) {
      console.error("claim_family_invite_email failed:", claimErr.message);
      return jsonRes({ success: false, error: "Could not send" }, 500);
    }
    if (!claim?.ok) return jsonRes({ success: false, reason: claim?.reason ?? "refused" });

    const invitedEmail: string = claim.email;
    const invitedByName: string = claim.inviter_name;
    const familyName: string = claim.family_name;

    let optOutLine = "";
    try {
      const token = await makeUnsubscribeToken(Deno.env.get("UNSUBSCRIBE_SECRET") || "", invitedEmail);
      optOutLine = `<p style="font-size:12px;color:#666">Do not want emails like this? <a href="${url}/functions/v1/email_optout?t=${token}">Stop them here</a>.</p>`;
    } catch (_) {
      await admin.rpc("release_family_invite_email", { p_invitation_id: claim.invitation_id, p_previous: claim.previous_sent_at ?? null });
      return jsonRes({ success: false, error: "Could not send" }, 500);
    }

    const htmlBody = `
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #1b7a4f; color: white; padding: 20px; border-radius: 8px 8px 0 0; text-align: center; }
            .content { background-color: #f9f9f9; padding: 20px; border-radius: 0 0 8px 8px; }
            .button { display: inline-block; background-color: #1b7a4f; color: white; padding: 12px 24px; border-radius: 6px; text-decoration: none; margin: 20px 0; }
            .footer { text-align: center; font-size: 12px; color: #666; margin-top: 20px; border-top: 1px solid #ddd; padding-top: 20px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>You're invited to Outlay!</h1>
            </div>
            <div class="content">
              <p>Hi ${esc(invitedEmail)},</p>
              <p>${esc(invitedByName) || "Someone"} has invited you to join their family in <strong>Outlay</strong> - the ultimate expense tracking app.</p>
              <p><strong>Family:</strong> ${esc(familyName) || "Shared Family Budget"}</p>
              <p>To accept, open the Outlay app, sign in with <strong>${esc(invitedEmail)}</strong>, then go to <strong>Settings &rarr; Pending Invitations</strong> and tap Accept.</p>
              <p>Don't have the app yet? Download Outlay from the App Store or Google Play, then sign in with this email address.</p>
              <p><strong>Note:</strong> This invitation will expire in 7 days.</p>
            </div>
            <div class="footer">
              <p>Outlay - Smart Expense Tracking | ${new Date().getFullYear()}</p>
              ${optOutLine}
            </div>
          </div>
        </body>
      </html>
    `;

    const result = await sendEmailViaSMTP(
      invitedEmail,
      "You're invited to Outlay!",
      htmlBody,
      Deno.env.get("NAMECHEAP_SMTP_USER") || "contact@outlayapp.net",
      "Outlay"
    );

    if (result.success) {
      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    } else {
      await admin.rpc("release_family_invite_email", { p_invitation_id: claim.invitation_id, p_previous: claim.previous_sent_at ?? null });
      console.error("family invitation email failed:", result.error);
      return jsonRes({ success: false, error: "Could not send" }, 500);
    }
  } catch (error) {
    console.error("❌ Error handling invitation:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}

Deno.serve(handleFamilyInvitation);
