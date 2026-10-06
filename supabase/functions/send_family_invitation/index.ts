
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

  try {
    const {
      familyId,
      invitedEmail,
      invitedByName,
      invitationToken,
      familyName,
    } = await req.json();

    if (!familyId || !invitedEmail || !invitationToken) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400 }
      );
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
      return new Response(
        JSON.stringify({ success: false, error: result.error }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
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
