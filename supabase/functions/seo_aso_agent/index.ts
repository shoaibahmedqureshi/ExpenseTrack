import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { Anthropic } from "https://esm.sh/@anthropic-ai/sdk@0.24.3";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") || "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""
);

const claude = new Anthropic({
  apiKey: Deno.env.get("CLAUDE_API_KEY") || "",
});

async function logAgentAction(action: string, status: "success" | "error", details: any) {
  await supabase.from("agent_logs").insert({
    agent_type: "seo_aso",
    action,
    status,
    details,
    run_date: new Date().toISOString(),
  });
}

async function findForumOpportunities() {
  console.log("🔍 Finding forum & community opportunities...");

  const response = await claude.messages.create({
    model: "claude-3-5-haiku-20241022",
    max_tokens: 1024,
    messages: [
      {
        role: "user",
        content: `Find 5 high-quality forums/communities for outlay.net (expense tracker).
        
Focus on:
1. Personal finance forums (Reddit r/finance, r/budgeting)
2. Budgeting communities
3. Q&A sites (Stack Exchange, Quora)
4. Niche forums

For each, provide:
- Forum name
- URL
- Category (finance/budgeting/expense-tracking)
- Difficulty (easy/medium/hard)
- Link anchor text idea
- Why it's good for backlinks

Return as JSON array.`,
      },
    ],
  });

  const content = response.content[0];
  if (content.type === "text") {
    try {
      const forums = JSON.parse(content.text);
      for (const forum of forums) {
        await supabase.from("forum_opportunities").insert({
          forum_name: forum.forum_name || forum.name,
          forum_url: forum.forum_url || forum.url,
          category: forum.category,
          difficulty: forum.difficulty,
          ranking_potential: 0.7,
          link_anchor_text: forum.anchor_text,
          target_url: "https://outlayapp.net",
          status: "discovered",
        }).catch(() => {}); // Ignore duplicates
      }
      return forums.length;
    } catch (e) {
      console.error("Error parsing forums:", e);
      return 0;
    }
  }
  return 0;
}

async function createProfileOpportunities() {
  console.log("👤 Identifying profile creation opportunities...");

  const response = await claude.messages.create({
    model: "claude-3-5-haiku-20241022",
    max_tokens: 512,
    messages: [
      {
        role: "user",
        content: `Suggest 4-5 platforms where Outlay (expense tracker) should have profiles:

Platforms:
1. Stack Overflow
2. Dev.to
3. Medium
4. Quora
5. Product Hunt
6. GitHub

For each:
- Profile URL format
- Bio keywords to use
- Content ideas
- Expected reach

Return as JSON array.`,
      },
    ],
  });

  const content = response.content[0];
  if (content.type === "text") {
    try {
      const profiles = JSON.parse(content.text);
      for (const profile of profiles) {
        await supabase.from("profile_links").insert({
          platform: profile.platform,
          platform_url: profile.platform_url,
          status: "planned",
          keywords_used: profile.keywords || ["expense tracking", "budgeting", "finance"],
        }).catch(() => {});
      }
      return profiles.length;
    } catch (e) {
      console.error("Error parsing profiles:", e);
      return 0;
    }
  }
  return 0;
}

async function suggestCommentOpportunities() {
  console.log("💬 Finding comment opportunities...");

  const response = await claude.messages.create({
    model: "claude-3-5-haiku-20241022",
    max_tokens: 512,
    messages: [
      {
        role: "user",
        content: `Suggest 3-4 popular questions/discussions on:
1. Reddit (r/personalfinance, r/budgeting)
2. Stack Exchange
3. Quora

For each:
- Discussion title
- URL
- Suggested comment (natural, helpful, mentions Outlay subtly)
- Expected upvotes

Return as JSON array.`,
      },
    ],
  });

  const content = response.content[0];
  if (content.type === "text") {
    try {
      const comments = JSON.parse(content.text);
      for (const comment of comments) {
        await supabase.from("comment_activities").insert({
          source_url: comment.url,
          source_type: comment.source_type || "forum",
          comment_text: comment.suggested_comment,
          status: "draft",
          keywords_mentioned: ["expense tracking", "budgeting", "personal finance"],
        }).catch(() => {});
      }
      return comments.length;
    } catch (e) {
      console.error("Error parsing comments:", e);
      return 0;
    }
  }
  return 0;
}

async function generateDailyReport() {
  console.log("📊 Generating daily SEO report...");

  const { data: activities } = await supabase
    .from("seo_activity_log")
    .select("*")
    .gte("created_at", new Date(Date.now() - 86400000).toISOString());

  const { data: forums } = await supabase
    .from("forum_opportunities")
    .select("*")
    .eq("status", "posted")
    .gte("post_date", new Date(Date.now() - 86400000).toISOString());

  const { data: comments } = await supabase
    .from("comment_activities")
    .select("*")
    .eq("status", "posted")
    .gte("posted_date", new Date(Date.now() - 86400000).toISOString());

  const summary = `Daily SEO Report:
- Forum posts: ${forums?.length || 0}
- Comments posted: ${comments?.length || 0}
- Activities logged: ${activities?.length || 0}
- Links created: ${(forums?.length || 0) + (comments?.length || 0)}`;

  await supabase.from("seo_daily_reports").insert({
    report_date: new Date().toISOString().split("T")[0],
    activities_completed: {
      forum_posts: forums?.length || 0,
      comments: comments?.length || 0,
      guest_posts: 0,
      profiles_created: 0,
    },
    links_created: (forums?.length || 0) + (comments?.length || 0),
    summary,
  }).catch(() => {});

  return summary;
}

async function main() {
  console.log("🚀 Enhanced SEO/ASO Agent Starting...");

  try {
    // Find forum opportunities
    const forumsFound = await findForumOpportunities();
    await logAgentAction("find_forum_opportunities", "success", { count: forumsFound });

    // Create profile opportunities
    const profilesFound = await createProfileOpportunities();
    await logAgentAction("create_profile_opportunities", "success", { count: profilesFound });

    // Suggest comments
    const commentsFound = await suggestCommentOpportunities();
    await logAgentAction("suggest_comments", "success", { count: commentsFound });

    // Generate daily report
    const report = await generateDailyReport();
    await logAgentAction("generate_daily_report", "success", { summary: report });

    console.log("✅ Enhanced SEO Agent completed successfully");

    return {
      status: "success",
      forums_found: forumsFound,
      profiles_suggested: profilesFound,
      comments_suggested: commentsFound,
      report_generated: true,
      timestamp: new Date().toISOString(),
    };
  } catch (error) {
    console.error("❌ Enhanced SEO Agent error:", error);

    await logAgentAction(
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
