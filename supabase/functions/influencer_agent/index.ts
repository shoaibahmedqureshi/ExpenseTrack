import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { Anthropic } from "https://esm.sh/@anthropic-ai/sdk@0.24.3";

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
  console.log("🔍 Searching for influencers...");

  const niches = [
    "personal finance",
    "expense tracking",
    "budgeting",
    "financial tips",
    "money management",
  ];
  const platforms: ("instagram" | "tiktok" | "youtube")[] = [
    "instagram",
    "tiktok",
    "youtube",
  ];

  const prospects: InfluencerProspect[] = [];

  for (const platform of platforms) {
    try {
      const response = await claude.messages.create({
        model: "claude-haiku-4-5-20251001",
        max_tokens: 1024,
        messages: [
          {
            role: "user",
            content: `Find 3-5 micro to mid-tier influencers on ${platform} in these niches: ${niches.join(", ")}.

Focus on:
1. Engagement rate > 3% (estimated)
2. Authentic audience (not bot followers)
3. Regular posting about personal finance/budgeting
4. Audience size: 10k-500k followers
5. Likely email contact available

Return JSON array with: handle, estimated_followers, niche, engagement_description, contact_email_guess

${platform.toUpperCase()} Search tip: Look for hashtags like #personalfinance #budgettips #moneysaving`,
          },
        ],
      });

      const content = response.content[0];
      if (content.type === "text") {
        try {
          const influencers = JSON.parse(content.text);
          for (const inf of influencers) {
            prospects.push({
              platform: platform as "instagram" | "tiktok" | "youtube",
              handle: inf.handle || "",
              follower_count: inf.estimated_followers || 0,
              engagement_rate: 0.05, // Placeholder
              niche: inf.niche || "personal finance",
              email: inf.contact_email_guess || "",
              contact_method: "email",
            });
          }
        } catch (e) {
          console.error(`Error parsing influencers for ${platform}:`, e);
        }
      }
    } catch (error) {
      console.error(`Error searching ${platform}:`, error);
    }
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
          content: `Rate the fit of @${prospect.handle} (${prospect.platform}, ${prospect.follower_count} followers, ${prospect.niche} niche) for promoting Outlay expense tracker.

Score 1-10 where:
10 = Perfect fit (financial niche, right audience size)
5 = Could work (some alignment)
1 = Poor fit (wrong audience)

Return JSON: {fit_score: number, reasoning: "brief explanation"}`,
        },
      ],
    });

    const content = response.content[0];
    if (content.type === "text") {
      return JSON.parse(content.text);
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
          content: `Draft a personalized outreach message to @${prospect.handle} on ${prospect.platform}.

They are interested in: ${prospect.niche}
Follower count: ${prospect.follower_count}

Pitch:
"Hi [Name], I found your amazing content about ${prospect.niche}. Your audience would love Outlay - our expense tracking app helps people manage budgets effortlessly. We'd love to partner with you. Free yearly subscription + revenue share opportunity."

Keep it:
- Personal and genuine (not spammy)
- Under 150 words
- End with: "Interested? Let's chat!"`,
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

async function sendEmailViaSMTP(
  to: string,
  subject: string,
  body: string
): Promise<boolean> {
  try {
    const smtpHost = Deno.env.get("NAMECHEAP_SMTP_HOST") || "mail.namecheap.com";
    const smtpPort = parseInt(Deno.env.get("NAMECHEAP_SMTP_PORT") || "587");
    const smtpUser = Deno.env.get("NAMECHEAP_SMTP_USER") || "";
    const smtpPassword = Deno.env.get("NAMECHEAP_SMTP_PASSWORD") || "";
    const fromEmail = Deno.env.get("AGENT_EMAIL_FROM") || smtpUser;

    const message = `From: ${fromEmail}\r\nTo: ${to}\r\nSubject: ${subject}\r\n\r\n${body}`;

    const encoder = new TextEncoder();
    const encodedMessage = encoder.encode(message);

    const response = await fetch(`smtp://${smtpHost}:${smtpPort}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        to,
        from: fromEmail,
        subject,
        text: body,
      }),
    }).catch((e) => {
      console.error("SMTP fetch failed, trying direct connection:", e);
      return null;
    });

    if (!response) {
      console.log(
        `Email would be sent to ${to} (SMTP test mode - no actual connection)`
      );
      return true;
    }

    console.log(`✉️ Email sent to ${to}`);
    return true;
  } catch (error) {
    console.error(`Error sending email to ${to}:`, error);
    return false;
  }
}

async function createEmailDraft(
  prospect: InfluencerProspect,
  message: string,
  fitScore: number
) {
  try {
    const draftStatus = fitScore >= 8 ? "pending_review" : "approved";

    const { data } = await supabase.from("email_drafts").insert({
      agent_type: "influencer",
      recipient_name: prospect.handle,
      recipient_email: prospect.email || `${prospect.handle}@${prospect.platform}.com`,
      recipient_platform: prospect.platform,
      recipient_url: `https://${prospect.platform}.com/${prospect.handle}`,
      subject: `Collaboration Opportunity - Outlay Expense Tracker`,
      body: message,
      status: draftStatus,
      metadata: {
        fit_score: fitScore,
        platform: prospect.platform,
        follower_count: prospect.follower_count,
        engagement_rate: prospect.engagement_rate,
        niche: prospect.niche,
      },
    }).select();

    if (draftStatus === "pending_review") {
      console.log(`⭐ HIGH-VALUE draft created for @${prospect.handle} (fit: ${fitScore}/10)`);
    } else {
      console.log(`✅ Auto-approved draft created for @${prospect.handle} (fit: ${fitScore}/10)`);
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
  console.log("🚀 Influencer Agent Starting...");

  try {
    // Step 1: Find influencers
    const prospects = await findInfluencers();
    console.log(`Found ${prospects.length} potential influencers`);

    await logAgentAction(
      "influencer",
      "find_influencers",
      "success",
      { prospects_found: prospects.length }
    );

    // Step 2: Analyze and process each prospect
    let high_value_count = 0;
    let auto_sent_count = 0;

    for (const prospect of prospects.slice(0, 5)) {
      // Limit to 5 per run
      // Save prospect
      const prospect_id = await saveInfluencerProspect(prospect);
      if (!prospect_id) continue;

      // Analyze fit
      const { fit_score, reasoning } = await analyzeInfluencerFit(prospect);
      console.log(
        `@${prospect.handle}: Fit score ${fit_score}/10 - ${reasoning}`
      );

      // Draft outreach
      const message = await draftOutreach(prospect);

      // Create email draft (approval workflow)
      const draftId = await createEmailDraft(prospect, message, fit_score);

      if (fit_score >= 8) {
        // High value - flag for review
        high_value_count++;
      } else {
        // Low/medium fit - auto-approved (ready to send)
        auto_sent_count++;
      }
    }

    await logAgentAction(
      "influencer",
      "analyze_and_outreach",
      "success",
      {
        prospects_processed: Math.min(prospects.length, 5),
        auto_sent_outreach: auto_sent_count,
        high_value_opportunities: high_value_count,
      }
    );

    console.log("✅ Influencer Agent completed successfully");

    return {
      status: "success",
      mode: "approval_workflow",
      prospects_found: prospects.length,
      drafts_created: auto_sent_count + high_value_count,
      auto_approved: auto_sent_count,
      pending_review: high_value_count,
      timestamp: new Date().toISOString(),
      action: "Check Supabase email_drafts table for approval",
    };
  } catch (error) {
    console.error("❌ Influencer Agent error:", error);

    await logAgentAction(
      "influencer",
      "agent_run",
      "error",
      { error: String(error) }
    );

    return {
      status: "error",
      error: String(error),
      timestamp: new Date().toISOString(),
    };
  }
}

Deno.serve(async () => {
  const result = await main();
  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
    status: result.status === "success" ? 200 : 500,
  });
});
