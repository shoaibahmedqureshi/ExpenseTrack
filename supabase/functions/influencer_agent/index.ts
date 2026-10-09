import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { Anthropic } from "https://esm.sh/@anthropic-ai/sdk@0.24.3";
import { sendEmail, isPlausibleRecipient } from "../_shared/email_service.ts";
import { requireServiceRole } from "../_shared/service_auth.ts";

interface InfluencerProspect {
  platform: "instagram" | "tiktok" | "youtube";
  handle: string;
  follower_count?: number;
  engagement_rate?: number;
  niche: string;
  email?: string;
  contact_method: string;
}

interface AgentApproval {
  agent_type: string;
  action_type: string;
  prospect_id: string;
  action_summary: string;
  approval_status: string;
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") || "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""
);

const claude = new Anthropic({
  apiKey: Deno.env.get("CLAUDE_API_KEY") || "",
});

const HIGH_VALUE_THRESHOLD =
  parseInt(Deno.env.get("HIGH_VALUE_THRESHOLD") || "1000");

async function logAgentAction(
  agent_type: string,
  action: string,
  status: "success" | "error" | "pending",
  details: Record<string, unknown>
) {
  await supabase.from("agent_logs").insert({
    agent_type,
    action,
    status,
    details,
    run_date: new Date().toISOString(),
  });
}

async function findInfluencers(): Promise<InfluencerProspect[]> {
  console.log("🔍 Searching for TikTok creators for Stitchify...");

  const niches = [
    "photography",
    "photo editing",
    "visual content",
    "image stitching",
    "photo combining",
    "creative content",
    "travel photography",
    "lifestyle photography",
    "content creation",
  ];

  // TikTok only for Stitchify
  const platform = "tiktok";
  const prospects: InfluencerProspect[] = [];

  try {
    const response = await claude.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 1024,
      messages: [
        {
          role: "user",
          content: `Find 5-10 TikTok creators in these niches: ${niches.join(", ")}.

Criteria:
1. Follower count: 1,000+ (micro-influencers welcome)
2. Engagement rate > 2% (estimated)
3. Authentic audience (not bot followers)
4. Regular posting about photography, visual content, or photo editing
5. Likely to have email or contact info available

These creators are perfect for promoting Stitchify - a photo combining/stitching app that helps combine multiple photos into one seamless image.

Return VALID JSON array with objects like:
[
  {"handle": "creator_name", "estimated_followers": 15000, "niche": "photography", "engagement_description": "high engagement", "contact_email_guess": "creator@example.com"},
  ...
]

IMPORTANT: Return valid JSON only, no markdown code blocks.

Hashtags to search: #photography #photoediting #contentcreator #visualcontent #photostitching #imagecombine #creativecontent #travelphotography`,
        },
      ],
    });

    const content = response.content[0];
    if (content.type === "text") {
      try {
        // Parse JSON - remove markdown code blocks if present
        let jsonText = content.text.trim();
        if (jsonText.startsWith("```json")) {
          jsonText = jsonText.replace(/^```json\n?/, "").replace(/\n?```$/, "");
        } else if (jsonText.startsWith("```")) {
          jsonText = jsonText.replace(/^```\n?/, "").replace(/\n?```$/, "");
        }

        const influencers = JSON.parse(jsonText);
        if (Array.isArray(influencers)) {
          for (const inf of influencers) {
            if (inf.handle && inf.estimated_followers >= 1000) {
              prospects.push({
                platform: "tiktok",
                handle: inf.handle || "",
                follower_count: inf.estimated_followers || 0,
                engagement_rate: 0.03, // Conservative estimate
                niche: inf.niche || "photography",
                email: inf.contact_email_guess || "",
                contact_method: "email",
              });
            }
          }
        }
      } catch (e) {
        console.error(`Error parsing TikTok creators:`, e);
        console.error(`Raw response: ${content.text.substring(0, 200)}`);
      }
    }
  } catch (error) {
    console.error(`Error searching TikTok:`, error);
  }

  return prospects;
}

async function analyzeInfluencerFit(prospect: InfluencerProspect): Promise<{
  fit_score: number;
  reasoning: string;
}> {
  try {
    const response = await claude.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 256,
      messages: [
        {
          role: "user",
          content: `Rate the fit of @${prospect.handle} (${prospect.platform}, ${prospect.follower_count} followers, niche: ${prospect.niche}) for promoting Stitchify - a photo combining/stitching app.

Scoring guide:
10 = Perfect fit: Creates photo content, travel/lifestyle creator, audience regularly shares photos
8-9 = Great fit: Photography/visual content, audience would benefit from photo combining
6-7 = Good fit: Content sometimes involves photos, could add value to their audience
4-5 = Moderate fit: Creative/visual content but not primarily photo-focused
1-3 = Poor fit: Niche doesn't align with photo content

Return VALID JSON: {"fit_score": number, "reasoning": "brief explanation"}`,
        },
      ],
    });

    const content = response.content[0];
    if (content.type === "text") {
      try {
        let jsonText = content.text.trim();
        if (jsonText.startsWith("```json")) {
          jsonText = jsonText.replace(/^```json\n?/, "").replace(/\n?```$/, "");
        } else if (jsonText.startsWith("```")) {
          jsonText = jsonText.replace(/^```\n?/, "").replace(/\n?```$/, "");
        }
        return JSON.parse(jsonText);
      } catch (e) {
        console.error(`Error parsing fit score:`, e);
      }
    }
  } catch (error) {
    console.error(`Error analyzing fit for @${prospect.handle}:`, error);
  }

  return { fit_score: 5, reasoning: "Unable to analyze" };
}

async function draftOutreach(prospect: InfluencerProspect): Promise<string> {
  try {
    const response = await claude.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 512,
      messages: [
        {
          role: "user",
          content: `Draft a personalized outreach message to @${prospect.handle} on TikTok.

They create content about: ${prospect.niche}
Follower count: ${prospect.follower_count}

Partnership offer - TWO premium apps, free for 1 year (up to 5 users each):
1. Stitchify Premium - Photo combining/stitching app (perfect for combining travel photos, event collages, before/afters)
2. Outlay Pro - Expense tracking app (for personal finance content)

Draft an authentic, casual message that:
1. Opens with genuine acknowledgment of their content style
2. Explains how BOTH apps benefit their audience
3. States the offer: "1 year free Stitchify Premium + 1 year free Outlay Pro (up to 5 users each)"
4. Emphasizes they can create authentic content with both tools
5. Keep it under 120 words
6. Ends with clear CTA ("Would you be interested?" or "Let me know if this is something you'd like to explore!")

Important: No revenue share mentioned. This is about providing free premium access for 1 year.
Keep it genuine, not sales-y. TikTok creators respond to personalized, honest pitches.`,
        },
      ],
    });

    const content = response.content[0];
    if (content.type === "text") {
      return content.text;
    }
  } catch (error) {
    console.error(
      `Error drafting outreach for @${prospect.handle}:`,
      error
    );
  }

  return "";
}

async function saveInfluencerProspect(prospect: InfluencerProspect) {
  try {
    // Check if already exists
    const { data: exists } = await supabase
      .from("influencer_prospects")
      .select("id")
      .eq("platform", prospect.platform)
      .eq("handle", prospect.handle)
      .single();

    if (!exists) {
      const { data } = await supabase
        .from("influencer_prospects")
        .insert(prospect)
        .select("id")
        .single();

      return data?.id;
    }
  } catch (error) {
    if (!error.message.includes("No rows found")) {
      console.error(`Error saving prospect @${prospect.handle}:`, error);
    }
  }
}

async function createEmailDraft(
  prospect: InfluencerProspect,
  message: string,
  fitScore: number
) {
  if (!prospect.email || !isPlausibleRecipient(prospect.email)) {
    console.log(`⏭️ No usable email for @${prospect.handle}; not drafting outreach`);
    return;
  }
  try {
    const draftStatus = fitScore >= 8 ? "pending_review" : "approved";

    const { data } = await supabase.from("email_drafts").insert({
      agent_type: "influencer",
      recipient_name: prospect.handle,
      recipient_email: prospect.email,
      recipient_platform: prospect.platform,
      recipient_url: `https://tiktok.com/@${prospect.handle}`,
      subject: `Partnership: Free Stitchify + Revenue Share for Creators`,
      body: message,
      status: draftStatus,
      metadata: {
        fit_score: fitScore,
        platform: prospect.platform,
        follower_count: prospect.follower_count,
        engagement_rate: prospect.engagement_rate,
        niche: prospect.niche,
        product: "stitchify",
        offer: "free_yearly_subscription + 20_percent_revenue_share",
      },
    }).select();

    if (draftStatus === "pending_review") {
      console.log(`⭐ HIGH-POTENTIAL creator for Stitchify: @${prospect.handle} (fit: ${fitScore}/10)`);
    } else {
      console.log(`✅ Outreach ready for @${prospect.handle} (fit: ${fitScore}/10)`);
    }

    return data?.[0]?.id;
  } catch (error) {
    console.error(`Error creating draft for @${prospect.handle}:`, error);
  }
}

async function flagHighValueOpportunity(
  prospect_id: string,
  prospect: InfluencerProspect,
  fit_score: number
) {
  if (fit_score >= 8) {
    // High fit score = high value
    await supabase.from("agent_approvals").insert({
      agent_type: "influencer",
      action_type: "send_outreach",
      prospect_id,
      action_summary: `Send outreach to @${prospect.handle} (${prospect.platform}, ${prospect.follower_count} followers, fit score: ${fit_score}/10)`,
      approval_status: "pending",
    });

    console.log(`⭐ HIGH-VALUE opportunity flagged: @${prospect.handle}`);
  }
}

async function main() {
  console.log("🚀 Stitchify Influencer Agent - EMAIL SENDING MODE");

  try {
    // Step 1: Get all approved emails ready to send
    const { data: approvedDrafts } = await supabase
      .from("email_drafts")
      .select("*")
      .eq("status", "approved")
      .eq("metadata->>product", "stitchify");

    console.log(`📧 Found ${approvedDrafts?.length || 0} approved emails to send`);

    let sent_count = 0;
    let failed_count = 0;

    // Step 2: Send each approved email
    if (approvedDrafts && approvedDrafts.length > 0) {
      for (const draft of approvedDrafts) {
        const result = await sendEmail({
          to: draft.recipient_email,
          subject: draft.subject,
          text: draft.body,
          categories: ["agent", "influencer-outreach", "stitchify"],
        });

        if (result.success) {
          sent_count++;
          await supabase
            .from("email_drafts")
            .update({ status: "sent", sent_date: new Date().toISOString() })
            .eq("id", draft.id);
          console.log(`✅ Email sent for @${draft.recipient_name}${result.redirectedTo ? " (redirected to test recipient)" : ""}`);
        } else if (result.skipped) {
          // Switched off or unusable address: leave the draft untouched, don't count as a failure.
          console.log(`⏸️ Not sent for @${draft.recipient_name}: ${result.error}`);
        } else {
          failed_count++;
          console.log(`❌ Failed for @${draft.recipient_name}: ${result.error}`);
        }
      }
    }

    // Step 3: Log the sending action
    await logAgentAction(
      "influencer",
      "send_emails",
      "success",
      {
        emails_sent: sent_count,
        emails_failed: failed_count,
        total_reach: approvedDrafts?.reduce(
          (sum, d) => sum + (d.metadata?.follower_count || 0),
          0
        ) || 0,
        product: "stitchify",
        platform: "tiktok",
      }
    );

    console.log("✅ Stitchify Email Campaign Completed");

    return {
      status: "success",
      product: "stitchify",
      platform: "tiktok",
      mode: "email_sending",
      emails_sent: sent_count,
      emails_failed: failed_count,
      total_emails: approvedDrafts?.length || 0,
      total_reach: approvedDrafts?.reduce(
        (sum, d) => sum + (d.metadata?.follower_count || 0),
        0
      ) || 0,
      offer: "1 year free Stitchify Premium + 1 year free Outlay Pro (up to 5 users each)",
      timestamp: new Date().toISOString(),
      next_step: "Monitor responses in email_drafts table",
    };
  } catch (error) {
    console.error("❌ Agent error:", error);

    await logAgentAction(
      "influencer",
      "agent_run",
      "error",
      { error: String(error), product: "stitchify" }
    );

    return {
      status: "error",
      product: "stitchify",
      error: String(error),
      timestamp: new Date().toISOString(),
    };
  }
}

Deno.serve(async (req) => {
  const denied = requireServiceRole(req);
  if (denied) return denied;
  const result = await main();
  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
    status: result.status === "success" ? 200 : 500,
  });
});
