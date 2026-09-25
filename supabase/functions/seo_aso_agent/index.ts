import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { Anthropic } from "https://esm.sh/@anthropic-ai/sdk@0.24.3";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") || "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""
);

const claude = new Anthropic({
  apiKey: Deno.env.get("CLAUDE_API_KEY") || "",
});

async function logActivity(
  activityType: string,
  targetUrl: string,
  status: "success" | "draft" | "error",
  details: any
) {
  await supabase.from("seo_activity_log").insert({
    activity_type: activityType,
    target_url: targetUrl,
    status,
    keywords_used: details.keywords || [],
    engagement_metric: details.engagement || 0,
  });
}

async function executeForumPosting() {
  console.log("📝 Executing forum posting strategy...");

  const response = await claude.messages.create({
    model: "claude-3-5-haiku-20241022",
    max_tokens: 1024,
    messages: [
      {
        role: "user",
        content: `Create 3 forum posts for Outlay (expense tracking app) that will be posted to:
1. Reddit r/personalfinance
2. Reddit r/budgeting  
3. Stack Exchange Money

For each:
- Title (natural, not spammy)
- Content (helpful, genuine, mentions Outlay naturally)
- Keywords used
- Expected engagement

Make them look organic - real user contributions, not advertisements.

Return as JSON array.`,
      },
    ],
  });

  const content = response.content[0];
  if (content.type === "text") {
    try {
      const posts = JSON.parse(content.text);
      
      for (const post of posts) {
        // Log as "ready to post" - manual approval needed for actual posting
        await supabase.from("forum_opportunities").insert({
          forum_name: post.forum,
          forum_url: post.url,
          category: "finance",
          difficulty: "medium",
          link_anchor_text: post.title,
          status: "posting_draft",
          notes: `Ready to post: ${post.title}`,
        }).catch(() => {});

        await logActivity(
          "forum_post_draft",
          post.url || "",
          "draft",
          {
            title: post.title,
            keywords: post.keywords,
            content_length: (post.content || "").length,
          }
        );
      }

      return {
        drafted: posts.length,
        status: "awaiting_approval",
        posts,
      };
    } catch (e) {
      console.error("Error parsing posts:", e);
      return { drafted: 0, status: "error" };
    }
  }
  return { drafted: 0, status: "error" };
}

async function createProfiles() {
  console.log("👤 Creating platform profiles with keywords...");

  const profiles = [
    {
      platform: "dev.to",
      bio: "Helping people master expense tracking and personal finance management with modern tools.",
      keywords: ["expense tracking", "budgeting", "personal finance", "fintech"],
    },
    {
      platform: "medium",
      bio: "Writing about financial wellness, budgeting strategies, and expense management for the modern person.",
      keywords: ["finance", "budgeting", "personal money management", "fintech"],
    },
    {
      platform: "quora",
      bio: "Helping people solve their budgeting and expense tracking challenges with practical advice.",
      keywords: ["budgeting", "expense management", "personal finance"],
    },
  ];

  for (const profile of profiles) {
    await supabase.from("profile_links").insert({
      platform: profile.platform,
      platform_url: `https://${profile.platform}`,
      bio: profile.bio,
      status: "planned",
      keywords_used: profile.keywords,
    }).catch(() => {});

    await logActivity(
      "profile_creation_plan",
      `https://${profile.platform}`,
      "draft",
      { keywords: profile.keywords }
    );
  }

  return {
    profiles_planned: profiles.length,
    platforms: profiles.map(p => p.platform),
  };
}

async function draftComments() {
  console.log("💬 Drafting community comments...");

  const response = await claude.messages.create({
    model: "claude-3-5-haiku-20241022",
    max_tokens: 512,
    messages: [
      {
        role: "user",
        content: `Draft 4 helpful comments for these Reddit discussions (natural, genuine, helpful):

1. "How do I track my expenses better?" on r/personalfinance
2. "Best budgeting apps?" on r/budgeting
3. "Tips for saving money?" on r/Money
4. "Expense tracking for freelancers?" on r/freelance

For each:
- Comment text (2-3 sentences, natural, mentions Outlay subtly)
- Why it's helpful
- Keywords naturally included
- Expected upvotes (1-100)

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
          source_url: comment.reddit_url || comment.url || "https://reddit.com",
          source_type: "forum",
          comment_text: comment.comment_text || comment.text,
          status: "draft",
          keywords_mentioned: comment.keywords || [],
        }).catch(() => {});

        await logActivity(
          "comment_draft",
          comment.url || "",
          "draft",
          { keywords: comment.keywords }
        );
      }

      return {
        comments_drafted: comments.length,
        status: "ready_for_review",
      };
    } catch (e) {
      console.error("Error parsing comments:", e);
      return { comments_drafted: 0, status: "error" };
    }
  }
  return { comments_drafted: 0, status: "error" };
}

async function generateReports() {
  console.log("📊 Generating activity reports...");

  const today = new Date().toISOString().split("T")[0];

  // Get today's activities
  const { data: activities } = await supabase
    .from("seo_activity_log")
    .select("*")
    .gte("created_at", `${today}T00:00:00`)
    .lte("created_at", `${today}T23:59:59`);

  const dailyReport = {
    report_date: today,
    activities_completed: {
      forum_posts: activities?.filter(a => a.activity_type === "forum_post_draft").length || 0,
      comments: activities?.filter(a => a.activity_type === "comment_draft").length || 0,
      profiles_created: activities?.filter(a => a.activity_type === "profile_creation_plan").length || 0,
      guest_posts: 0,
    },
    links_created: activities?.length || 0,
    summary: `Daily SEO Report: ${activities?.length || 0} activities logged. Forums drafted, profiles planned, comments ready for review.`,
  };

  await supabase.from("seo_daily_reports").insert(dailyReport).catch(() => {});

  return dailyReport;
}

async function main() {
  console.log("🚀 Enhanced SEO Agent - AUTONOMOUS MODE");
  console.log("=======================================");
  console.log("");

  try {
    // Execute forum posting strategy
    const forumResults = await executeForumPosting();
    console.log(`✅ Forum posts drafted: ${forumResults.drafted}`);

    // Create profile strategies
    const profileResults = await createProfiles();
    console.log(`✅ Profiles planned: ${profileResults.profiles_planned}`);

    // Draft community comments
    const commentResults = await draftComments();
    console.log(`✅ Comments drafted: ${commentResults.comments_drafted}`);

    // Generate reports
    const dailyReport = await generateReports();
    console.log(`✅ Daily report generated`);

    console.log("");
    console.log("📋 EXECUTION SUMMARY:");
    console.log(`   • Forum Posts: ${forumResults.drafted} (ready for posting)`);
    console.log(`   • Profiles: ${profileResults.profiles_planned} (planned for creation)`);
    console.log(`   • Comments: ${commentResults.comments_drafted} (ready for posting)`);
    console.log("");
    console.log("⏳ Next steps:");
    console.log("   1. Review forum_opportunities table for posts to execute");
    console.log("   2. Approve comments in comment_activities table");
    console.log("   3. Create profiles listed in profile_links table");
    console.log("");

    return {
      status: "success",
      forum_posts_drafted: forumResults.drafted,
      profiles_planned: profileResults.profiles_planned,
      comments_drafted: commentResults.comments_drafted,
      ready_for_execution: true,
      timestamp: new Date().toISOString(),
    };
  } catch (error) {
    console.error("❌ Error:", error);
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
