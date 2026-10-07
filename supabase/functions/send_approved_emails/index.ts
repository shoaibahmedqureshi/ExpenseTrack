import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { sendEmail } from "../_shared/email_service.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") || "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""
);

async function main() {
  console.log("🚀 Send Approved Emails\n");

  try {
    // Fetch all approved emails
    const { data: approvedEmails, error } = await supabase
      .from("influencer_outreach")
      .select("id, prospect_id, subject, body")
      .eq("status", "approved")
      .limit(10);

    if (error) throw error;

    if (!approvedEmails || approvedEmails.length === 0) {
      return { status: "success", message: "No approved emails", emails_sent: 0 };
    }

    console.log(`📧 Found ${approvedEmails.length} approved email(s)\n`);

    let successCount = 0;
    let failureCount = 0;

    for (const email of approvedEmails) {
      const { data: prospect } = await supabase
        .from("influencer_prospects")
        .select("email, handle")
        .eq("id", email.prospect_id)
        .single();

      if (!prospect?.email) {
        failureCount++;
        continue;
      }

      const result = await sendEmail({
        to: prospect.email,
        subject: email.subject,
        text: email.body,
        categories: ["agent", "influencer-outreach"],
      });

      if (result.success) {
        await supabase
          .from("influencer_outreach")
          .update({
            status: "sent",
            sent_date: new Date().toISOString(),
          })
          .eq("id", email.id);

        successCount++;
      } else {
        failureCount++;
      }

      await new Promise((resolve) => setTimeout(resolve, 1000));
    }

    await supabase.from("agent_logs").insert({
      agent_type: "email_sender",
      action: "send_approved_emails",
      status: "success",
      details: { emails_sent: successCount, emails_failed: failureCount },
      run_date: new Date().toISOString(),
    });

    console.log(`\n✅ Sent: ${successCount}, Failed: ${failureCount}`);

    return {
      status: "success",
      emails_sent: successCount,
      emails_failed: failureCount,
      timestamp: new Date().toISOString(),
    };
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    console.error(`❌ Error: ${errorMessage}`);

    return { status: "error", error: errorMessage };
  }
}

Deno.serve(async () => {
  const result = await main();
  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
    status: result.status === "success" ? 200 : 500,
  });
});
