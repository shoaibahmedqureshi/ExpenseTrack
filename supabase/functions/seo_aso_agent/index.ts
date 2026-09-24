import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { Anthropic } from "https://esm.sh/@anthropic-ai/sdk@0.24.3";

interface AgentLog {
  agent_type: string;
  action: string;
  status: "success" | "error" | "pending";
  details: Record<string, unknown>;
  error_message?: string;
}

interface LinkOpportunity {
  domain: string;
  url: string;
  domain_authority?: number;
  relevance_score?: number;
  email?: string;
  contact_name?: string;
  subscription_offered: string;
  subscription_code: string;
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") || "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""
);

const claude = new Anthropic({
  apiKey: Deno.env.get("CLAUDE_API_KEY") || "",
});

async function logAgentAction(log: AgentLog) {
  await supabase.from("agent_logs").insert({
    ...log,
    run_date: new Date().toISOString(),
  });
}

async function generateSubscriptionCode(): Promise<string> {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let code = "";
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

async function findLinkOpportunities(): Promise<LinkOpportunity[]> {
  console.log("🔍 Starting link opportunity discovery...");

  const apps = [
    {
      domain: "outlayapp.net",
      description: "Personal expense tracker app for all budgeting needs",
      keywords: "expense tracking, budgeting, financial management",
    },
    {
      domain: "technologistan.pk",
      description: "Electronics and device marketplace",
      keywords: "technology, electronics, devices marketplace",
    },
  ];

  const opportunities: LinkOpportunity[] = [];

  for (const app of apps) {
    try {
      const response = await claude.messages.create({
        model: "claude-3-5-haiku-20241022",
        max_tokens: 1024,
        messages: [
          {
            role: "user",
            content: `Find 3-5 high-quality link building opportunities for "${app.domain}" (${app.description}).
            
Keywords: ${app.keywords}

For each opportunity, suggest:
1. Target website (niche relevant, high domain authority)
2. Contact email if possible
3. Pitch angle (how ${app.domain} provides value to their audience)

Return as JSON array with fields: domain, suggested_content, pitch_angle, potential_contact`,
          },
        ],
      });

      const content = response.content[0];
      if (content.type === "text") {
        // Parse Claude's response and create opportunities
        const opportunities_found = JSON.parse(content.text);
        
        for (const opp of opportunities_found) {
          const code = await generateSubscriptionCode();
          opportunities.push({
            domain: opp.domain || "",
            url: `https://${opp.domain}`,
            domain_authority: 45, // Placeholder - would need API call
            relevance_score: 0.8,
            email: opp.potential_contact || "",
            contact_name: "",
            subscription_offered: "expense_tracker_pro_annual",
            subscription_code: code,
          });
        }
      }
    } catch (error) {
      console.error(`Error finding opportunities for ${app.domain}:`, error);
    }
  }

  return opportunities;
}

async function auditContent() {
  console.log("📊 Starting content audit...");

  const apps = ["outlayapp.net", "technologistan.pk"];

  for (const domain of apps) {
    try {
      const response = await claude.messages.create({
        model: "claude-3-5-haiku-20241022",
        max_tokens: 512,
        messages: [
          {
            role: "user",
            content: `Perform an SEO audit checklist for ${domain}:
1. Title tag optimization
2. Meta description
3. Header structure (H1, H2, H3)
4. Internal linking opportunities
5. Mobile responsiveness
6. Page load speed considerations
7. Content depth and comprehensiveness

Return as JSON with priority levels (critical, high, medium, low) and specific recommendations.`,
          },
        ],
      });

      const content = response.content[0];
      if (content.type === "text") {
        const findings = JSON.parse(content.text);
        
        await supabase.from("guest_post_audits").insert({
          app_domain: domain,
          audit_type: "seo",
          findings,
          recommendations: findings,
          priority: "high",
          status: "completed",
        });
      }
    } catch (error) {
      console.error(`Error auditing ${domain}:`, error);
    }
  }
}

async function draftPitches(opportunities: LinkOpportunity[]) {
  console.log("✍️ Drafting guest post pitches...");

  for (const opp of opportunities.slice(0, 3)) {
    // Limit to 3 per run
    try {
      const response = await claude.messages.create({
        model: "claude-3-5-haiku-20241022",
        max_tokens: 512,
        messages: [
          {
            role: "user",
            content: `Draft a personalized guest post pitch for ${opp.domain}.
We represent Outlay (${opp.subscription_offered || "expense tracker app"}).

Pitch angle: We offer ${opp.subscription_offered} (free yearly subscription) for guest post.

Create:
1. Subject line
2. Opening sentence (personalized to their audience)
3. Value proposition (why our app helps their readers)
4. Call to action (free subscription link)

Keep it under 200 words. Be concise and professional.`,
          },
        ],
      });

      const content = response.content[0];
      if (content.type === "text") {
        const { subject_line, body } = JSON.parse(content.text);
        
        const { data: linkOpp } = await supabase
          .from("link_opportunities")
          .select("id")
          .eq("domain", opp.domain)
          .single();

        if (linkOpp) {
          await supabase.from("guest_post_pitches").insert({
            link_opportunity_id: linkOpp.id,
            title: subject_line,
            pitch_text: body,
            status: "draft",
          });
        }
      }
    } catch (error) {
      console.error(`Error drafting pitch for ${opp.domain}:`, error);
    }
  }
}

async function saveLinkOpportunities(opportunities: LinkOpportunity[]) {
  console.log(`💾 Saving ${opportunities.length} link opportunities...`);

  for (const opp of opportunities) {
    try {
      // Check if already exists
      const { data: exists } = await supabase
        .from("link_opportunities")
        .select("id")
        .eq("domain", opp.domain)
        .single();

      if (!exists) {
        await supabase.from("link_opportunities").insert(opp);
      }
    } catch (error) {
      console.error(`Error saving opportunity ${opp.domain}:`, error);
    }
  }
}

async function main() {
  console.log("🚀 SEO/ASO Agent Starting...");
  
  try {
    // Step 1: Find link opportunities
    const opportunities = await findLinkOpportunities();
    await saveLinkOpportunities(opportunities);

    await logAgentAction({
      agent_type: "seo_aso",
      action: "find_link_opportunities",
      status: "success",
      details: { opportunities_found: opportunities.length },
    });

    // Step 2: Audit content
    await auditContent();

    await logAgentAction({
      agent_type: "seo_aso",
      action: "content_audit",
      status: "success",
      details: { apps_audited: 2 },
    });

    // Step 3: Draft pitches
    await draftPitches(opportunities);

    await logAgentAction({
      agent_type: "seo_aso",
      action: "draft_pitches",
      status: "success",
      details: { pitches_drafted: Math.min(opportunities.length, 3) },
    });

    console.log("✅ SEO/ASO Agent completed successfully");

    return {
      status: "success",
      opportunities_found: opportunities.length,
      timestamp: new Date().toISOString(),
    };
  } catch (error) {
    console.error("❌ SEO/ASO Agent error:", error);

    await logAgentAction({
      agent_type: "seo_aso",
      action: "agent_run",
      status: "error",
      details: { error: String(error) },
      error_message: String(error),
    });

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
