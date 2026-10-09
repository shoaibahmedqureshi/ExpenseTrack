import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { Anthropic } from "https://esm.sh/@anthropic-ai/sdk@0.24.3";
import { requireServiceRole } from "../_shared/service_auth.ts";

const supabaseUrl = Deno.env.get("SB_URL");
const supabaseKey = Deno.env.get("SB_SERVICE_ROLE_KEY");

if (!supabaseUrl || !supabaseKey) {
  console.error("❌ Missing Supabase credentials:");
  console.error(`   SB_URL: ${supabaseUrl ? "✓" : "✗ NOT SET"}`);
  console.error(`   SB_SERVICE_ROLE_KEY: ${supabaseKey ? "✓" : "✗ NOT SET"}`);
}

const supabase = createClient(supabaseUrl || "", supabaseKey || "");
const claude = new Anthropic({
  apiKey: Deno.env.get("CLAUDE_API_KEY") || "",
});

interface GrowthTask {
  platform: "reddit" | "product_hunt" | "hacker_news" | "pinterest" | "aso" | "reviews";
  task_key: string;
  title: string;
  description: string;
  content_brief?: string;
  target_audience?: string;
  estimated_impact?: "high" | "medium" | "low";
}

async function getGrowthTasks(): Promise<GrowthTask[]> {
  console.log("📋 Fetching KAN-19 growth tasks from Jira configuration...\n");

  // KAN-20 through KAN-39 growth tasks
  const tasks: GrowthTask[] = [
    // Reddit Tasks
    {
      platform: "reddit",
      task_key: "KAN-20",
      title: "Launch r/personalfinance + r/budgeting threads",
      description: "Post Outlay as budget tracking solution on Reddit's largest finance communities",
      content_brief: "Personal finance management, expense tracking, budget optimization",
      target_audience: "Individual expense trackers, budget enthusiasts, personal finance subreddits",
      estimated_impact: "high",
    },
    {
      platform: "reddit",
      task_key: "KAN-21",
      title: "r/pakistan dedicated threads (Urdu/English)",
      description: "Target Pakistani audience with localized Outlay messaging",
      content_brief: "Personal finance in Urdu/English, expense tracking for South Asia",
      target_audience: "Pakistani users, South Asian expat communities",
      estimated_impact: "high",
    },
    {
      platform: "reddit",
      task_key: "KAN-22",
      title: "Reply to budget/finance questions with Outlay link",
      description: "Strategic comments in relevant threads offering Outlay as solution",
      content_brief: "Contextual recommendations, helpful comments with value prop",
      target_audience: "Budget/finance discussion participants",
      estimated_impact: "medium",
    },

    // Product Hunt Tasks
    {
      platform: "product_hunt",
      task_key: "KAN-23",
      title: "Ship Outlay on Product Hunt (iOS + Android)",
      description: "Official Product Hunt launch with full description and visuals",
      content_brief: "Tagline, full description, benefits, pricing, demo link",
      target_audience: "Product Hunt early adopters, makers, tech-savvy users",
      estimated_impact: "high",
    },
    {
      platform: "product_hunt",
      task_key: "KAN-24",
      title: "Engage comments & respond to feedback",
      description: "Active engagement on Product Hunt launch day + follow-up",
      content_brief: "Quick response templates for common questions",
      target_audience: "Product Hunt community, launch day participants",
      estimated_impact: "high",
    },

    // Hacker News Tasks
    {
      platform: "hacker_news",
      task_key: "KAN-25",
      title: "Launch Outlay on Hacker News (Show HN thread)",
      description: "Show HN post for Outlay with technical architecture highlight",
      content_brief: "Technical approach, Flutter stack, open challenges",
      target_audience: "HN builders, developers, early adopters",
      estimated_impact: "medium",
    },

    // Pinterest Tasks
    {
      platform: "pinterest",
      task_key: "KAN-26",
      title: "Create Stitchify short-form video series",
      description: "TikTok/Reels-style videos showcasing Stitchify (screenshot tool)",
      content_brief: "15-30s clips: use cases, before/after, quick wins",
      target_audience: "Social media users, visual learners, short-form video audience",
      estimated_impact: "medium",
    },
    {
      platform: "pinterest",
      task_key: "KAN-27",
      title: "Pinterest pin designs for Outlay (budget templates)",
      description: "Eye-catching pins linking to budget guides, expense tracking tips",
      content_brief: "Design briefs: colors, fonts, messaging, CTA buttons",
      target_audience: "Pinterest users interested in budgeting, personal finance",
      estimated_impact: "low",
    },

    // ASO Tasks
    {
      platform: "aso",
      task_key: "KAN-28",
      title: "Optimize iOS App Store listing (title, keywords, screenshots)",
      description: "Rewrite for keyword coverage: expense tracking, budget, personal finance",
      content_brief: "New title, subtitle, keyword optimization, screenshot copy",
      target_audience: "App Store search algorithms, iOS users",
      estimated_impact: "high",
    },
    {
      platform: "aso",
      task_key: "KAN-29",
      title: "Optimize Android Play Store listing (same as iOS)",
      description: "Rewrite for keyword coverage and engagement on Play Store",
      content_brief: "Title, short description, full description, keyword strategy",
      target_audience: "Play Store search algorithms, Android users",
      estimated_impact: "high",
    },

    // Review Seeding
    {
      platform: "reviews",
      task_key: "KAN-30",
      title: "Seed positive reviews from beta testers",
      description: "Encourage existing users to leave 5-star reviews on both app stores",
      content_brief: "Template message, review request scripts, timing strategy",
      target_audience: "Beta testers, early users, influencers",
      estimated_impact: "high",
    },

    // Cross-Promotion
    {
      platform: "reddit",
      task_key: "KAN-31",
      title: "Cross-promote Outlay ↔ Stitchify on both apps",
      description: "In-app prompts suggesting Stitchify to Outlay users and vice versa",
      content_brief: "Copy for in-app cross-promo, timing, targeting logic",
      target_audience: "Existing user bases",
      estimated_impact: "medium",
    },

    // Influencer Seeding (to leverage agents)
    {
      platform: "reddit",
      task_key: "KAN-32",
      title: "Micro-influencer outreach (Twitter/LinkedIn)",
      description: "Identify and contact personal finance micro-influencers for reviews",
      content_brief: "Influencer criteria, pitch template, free code offers",
      target_audience: "Personal finance creators, finance bloggers",
      estimated_impact: "high",
    },

    // Week 1-2 tracking
    {
      platform: "reddit",
      task_key: "KAN-33",
      title: "Weekly acquisition tracking & reporting",
      description: "Track installs, reviews, organic sources, conversion metrics",
      content_brief: "Tracking dashboard, metrics to monitor, reporting format",
      target_audience: "Internal tracking",
      estimated_impact: "high",
    },

    // Additional reddit/content tasks
    {
      platform: "reddit",
      task_key: "KAN-34",
      title: "Create comparison thread: Outlay vs (Expensify, YNAB, Mint)",
      description: "Educational thread showing Outlay's advantages",
      content_brief: "Feature comparison, pricing, user experience comparison",
      target_audience: "Finance/budgeting communities",
      estimated_impact: "medium",
    },
    {
      platform: "reddit",
      task_key: "KAN-35",
      title: "Launch Stitchify on Reddit (r/screenshots, r/softwarereleases)",
      description: "Announce Stitchify with use cases for screenshot organization",
      content_brief: "Problem statement, solution, demo, availability",
      target_audience: "Screenshot tool users, productivity enthusiasts",
      estimated_impact: "low",
    },

    // Remaining growth tasks
    {
      platform: "product_hunt",
      task_key: "KAN-36",
      title: "Submit Stitchify to Product Hunt (1-2 weeks after Outlay)",
      description: "Secondary launch for Stitchify with momentum from Outlay",
      content_brief: "Tagline, description, visuals, positioning vs screenshot tools",
      target_audience: "Product Hunt, productivity tool users",
      estimated_impact: "medium",
    },
    {
      platform: "pinterest",
      task_key: "KAN-37",
      title: "Outlay budget guide blog posts (SEO content)",
      description: "Create 3-5 budget guide articles optimized for organic search",
      content_brief: "Topic ideas, outline structure, keyword targets",
      target_audience: "Organic search, budget template seekers",
      estimated_impact: "medium",
    },
    {
      platform: "aso",
      task_key: "KAN-38",
      title: "A/B test app screenshots for conversion optimization",
      description: "Variant testing on top screenshots to maximize install conversion",
      content_brief: "Screenshot variants, testing methodology, success metrics",
      target_audience: "App Store optimization",
      estimated_impact: "high",
    },
    {
      platform: "reviews",
      task_key: "KAN-39",
      title: "Follow up with reviewers, incentivize high-quality feedback",
      description: "Send thank you messages, ask for detailed reviews, offer rewards",
      content_brief: "Follow-up email template, incentive strategy, response handling",
      target_audience: "Review contributors",
      estimated_impact: "medium",
    },
  ];

  console.log(`✅ Loaded ${tasks.length} growth execution tasks\n`);
  return tasks;
}

async function generateExecutionPlan(task: GrowthTask): Promise<string> {
  console.log(`📝 Generating execution plan for ${task.task_key}: ${task.title}...\n`);

  const prompt = `You are a growth strategy expert. Create a detailed, actionable execution plan for this growth task:

Task: ${task.task_key} - ${task.title}
Platform: ${task.platform}
Description: ${task.description}
Target Audience: ${task.target_audience || "General"}
Estimated Impact: ${task.estimated_impact || "unknown"}

Generate:
1. Step-by-step execution checklist (5-7 steps)
2. Content to create (copy, visuals, scripts)
3. Success metrics to track
4. Timeline estimate
5. Potential blockers and mitigation

Be specific and actionable - this will be executed by a marketing coordinator.`;

  const message = await claude.messages.create({
    model: "claude-haiku-4.5-20241022",
    max_tokens: 1024,
    messages: [
      {
        role: "user",
        content: prompt,
      },
    ],
  });

  return message.content[0].type === "text" ? message.content[0].text : "";
}

async function storeExecutionPlans(tasks: GrowthTask[], plans: Map<string, string>) {
  console.log("💾 Storing growth execution plans to database...\n");

  let stored = 0;
  for (const task of tasks) {
    const plan = plans.get(task.task_key) || "";

    const { error, data } = await supabase
      .from("growth_tasks")
      .upsert({
        task_key: task.task_key,
        platform: task.platform,
        title: task.title,
        description: task.description,
        target_audience: task.target_audience,
        estimated_impact: task.estimated_impact,
        execution_plan: plan,
        status: "ready_for_execution",
        created_at: new Date().toISOString(),
      }, { onConflict: "task_key" });

    if (error) {
      console.error(`❌ Error storing ${task.task_key}:`, error);
    } else {
      stored++;
      console.log(`✅ Stored: ${task.task_key}`);
    }
  }

  console.log(`\n✅ Total stored: ${stored} growth execution plans\n`);
  return stored;
}

async function main() {
  console.log("🚀 Growth Execution Agent - KAN-19 Marketing Tasks\n");
  console.log("═══════════════════════════════════════════════════\n");

  try {
    // Get all KAN-19 growth tasks
    const tasks = await getGrowthTasks();

    // Generate execution plans for each task
    const executionPlans = new Map<string, string>();
    for (const task of tasks) {
      try {
        const plan = await generateExecutionPlan(task);
        executionPlans.set(task.task_key, plan);
      } catch (err) {
        console.error(`Error generating plan for ${task.task_key}:`, err);
      }
    }

    // Store all plans to database
    const stored = await storeExecutionPlans(tasks, executionPlans);

    console.log("═══════════════════════════════════════════════════\n");
    console.log("✅ Growth Execution Agent Complete!\n");

    return {
      status: "success",
      tasks_loaded: tasks.length,
      plans_generated: executionPlans.size,
      plans_stored: stored,
      platforms_covered: [...new Set(tasks.map(t => t.platform))].sort(),
      next_step: "Review execution plans in growth_tasks table, prioritize by impact, assign to team members",
      timestamp: new Date().toISOString(),
    };
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    console.error(`❌ Error: ${errorMessage}`);

    return { status: "error", error: errorMessage };
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
