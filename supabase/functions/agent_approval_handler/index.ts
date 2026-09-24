import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") || "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""
);

interface ApprovalRequest {
  approval_id: string;
  action: "approve" | "reject";
}

async function executeApprovedAction(approval: any) {
  try {
    switch (approval.action_type) {
      case "send_outreach":
        // Get the outreach details
        const { data: outreach } = await supabase
          .from("influencer_outreach")
          .select("*")
          .eq("prospect_id", approval.prospect_id)
          .order("created_at", { ascending: false })
          .limit(1)
          .single();

        if (outreach) {
          // In a real scenario, this would send an email via SMTP
          // For now, we'll just log and update status
          console.log("📧 Would send email to prospect:", approval.prospect_id);

          // Update outreach status
          await supabase
            .from("influencer_outreach")
            .update({ sent_date: new Date().toISOString(), status: "sent" })
            .eq("id", outreach.id);

          // Update prospect status
          await supabase
            .from("influencer_prospects")
            .update({
              outreach_status: "contacted",
              first_contact_date: new Date().toISOString(),
            })
            .eq("id", approval.prospect_id);
        }
        break;

      case "sign_contract":
        // Update onboarding status
        const { data: onboarding } = await supabase
          .from("influencer_onboarding")
          .select("id")
          .eq("prospect_id", approval.prospect_id)
          .single();

        if (onboarding) {
          await supabase
            .from("influencer_onboarding")
            .update({ status: "contract_signed" })
            .eq("id", onboarding.id);
        }
        break;

      case "payment_approval":
        console.log("💰 Payment approved for:", approval.prospect_id);
        // Log payment approval
        break;
    }

    // Update approval record
    await supabase
      .from("agent_approvals")
      .update({
        approval_status: "approved",
        approved_date: new Date().toISOString(),
        executed_date: new Date().toISOString(),
      })
      .eq("id", approval.id);

    return { success: true, action: approval.action_type };
  } catch (error) {
    console.error("Error executing approval:", error);
    throw error;
  }
}

async function rejectApproval(approval_id: string) {
  try {
    await supabase
      .from("agent_approvals")
      .update({
        approval_status: "rejected",
        approved_date: new Date().toISOString(),
      })
      .eq("id", approval_id);

    return { success: true, status: "rejected" };
  } catch (error) {
    console.error("Error rejecting approval:", error);
    throw error;
  }
}

async function getPendingApprovals() {
  try {
    const { data } = await supabase
      .from("agent_approvals")
      .select("*")
      .eq("approval_status", "pending")
      .order("created_at", { ascending: false });

    return data || [];
  } catch (error) {
    console.error("Error fetching pending approvals:", error);
    return [];
  }
}

Deno.serve(async (req) => {
  try {
    // Handle CORS
    if (req.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });
    }

    const url = new URL(req.url);

    // GET /approval-handler - List pending approvals
    if (req.method === "GET" && url.pathname === "/functions/v1/agent_approval_handler") {
      const approvals = await getPendingApprovals();
      return new Response(JSON.stringify(approvals), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // POST /approval-handler - Process approval/rejection
    if (req.method === "POST") {
      const body = (await req.json()) as ApprovalRequest;

      if (!body.approval_id || !body.action) {
        return new Response(
          JSON.stringify({ error: "Missing approval_id or action" }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        );
      }

      // Get the approval
      const { data: approval } = await supabase
        .from("agent_approvals")
        .select("*")
        .eq("id", body.approval_id)
        .single();

      if (!approval) {
        return new Response(JSON.stringify({ error: "Approval not found" }), {
          status: 404,
          headers: { "Content-Type": "application/json" },
        });
      }

      let result;
      if (body.action === "approve") {
        result = await executeApprovedAction(approval);
      } else if (body.action === "reject") {
        result = await rejectApproval(body.approval_id);
      } else {
        return new Response(JSON.stringify({ error: "Invalid action" }), {
          status: 400,
          headers: { "Content-Type": "application/json" },
        });
      }

      return new Response(JSON.stringify(result), {
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Handler error:", error);
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
