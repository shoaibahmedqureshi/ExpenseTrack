# Growth Plan — Outlay & Stitchify (Beyond Marketing)

Marketing (SEO, content, ads) brings people to the door. This is about mechanics *inside* the
product that make growth compound on its own — invites that pay for themselves, and features that
are viral by design rather than by campaign.

## 1. Referral / invite program

This is a separate thing from the influencer revenue-share system you already have live — that's
creator partnerships with a revenue cut; this is peer-to-peer, every regular user inviting friends.
Worth building because the underlying infrastructure already exists and is proven: `influencer_codes`
already tracks unique codes, redemption, and revenue share end-to-end. A user-referral program is
the same mechanic pointed at regular users instead of creators — new `referral_codes` table (or a
`source` column distinguishing "influencer" vs "user-referral" on the existing table), same
redemption-tracking logic, same Apple Promotional Offers / Play Billing developer-determined-offer
plumbing from the in-app redemption work already planned.

**Incentive structure — double-sided, not cash:**
- Referrer gets something when their invite installs *and* becomes active (opens the app 3+ times,
  or logs a real expense) — not just on install, to filter out low-quality invites.
- Referee gets a small welcome bonus (e.g., 14 days of Pro free) — removes first-use friction and
  makes accepting the invite feel like a gift, not a favor to the referrer.
- Avoid cash/credit incentives — they attract people gaming the system for the reward, not people
  who'll actually use the app. Feature-based rewards (extra Pro days, unlock a premium report type)
  self-select for genuine interest.
- Cap it so it doesn't become a discount-stacking exploit (e.g., max 3 months of free Pro from
  referrals per year).

## 2. Bill / event expense split — this is the real growth engine (Outlay)

This is the single highest-leverage feature available to an expense tracker, because splitting a
bill *requires* other people — it's viral by construction, not by incentive. Splitwise built an
entire company on this loop; it's proven, not speculative.

**Why it works as growth, not just a feature:**
- Person A splits a dinner/trip/rent with Person B, C, D. Those people get a notification
  ("Sarah added you to 'Goa Trip' — you owe ₹1,200") via SMS/WhatsApp/email deep link.
- Critical design decision: **don't gate viewing behind an app install.** Let the invited person
  see their share on a lightweight web page first (this is exactly what the free
  `bill-splitter-calculator.html` tool you already built and shipped could become — the "view your
  split" landing page for non-users). Force install only when they want to *settle up* or track
  their own spending going forward. Splitwise, Venmo, and every successful split-expense product
  converged on this same "view frictionless, install to act" pattern — it's not a guess.
- Every event with 3+ people multiplies distribution: one active user pulls in N non-users per
  event, repeatedly, for free.

**Beyond one-off splits — shared groups for retention, not just virality:**
Recurring group expense tracking (a shared household, a shared trip budget) does something a
one-off split doesn't: once 2+ people are relying on the same group, switching cost goes up for
*everyone* in it, which improves retention for the whole cohort, not just the inviter. Worth
building "Groups" as a first-class object (not just "splits"), with the one-off bill split as the
lightweight entry point into a group that can persist.

**Engineering note:** this needs real multi-user shared-access tables (a group's expenses visible
to all members, not just the owner) — a meaningfully bigger Supabase/RLS lift than anything in the
app today. Worth scoping as its own epic before committing to a timeline; flagging now so it's not
underestimated. [[punch_list_status]] already has an open RLS bug on `profiles` — resolve that
first, since shared-group RLS policies will be more complex than what's causing that bug.

## 3. Stitchify — a different app needs a different loop

Bill-splitting obviously doesn't transfer to a photo tool. Two mechanics that do fit a
utility/creative app, both proven elsewhere:

- **Watermark as passive distribution:** if the free tier doesn't already add a small "Made with
  Stitchify" mark on exported images, add one. Every image a free user shares (which is the entire
  point of the app — combined images get sent to people) becomes a soft ad. Removing it is a
  natural, well-understood premium/referral unlock (Canva and CapCut both use exactly this
  mechanic). Low effort, direct exposure to exactly the audience who'd want the app (people already
  receiving shared images from friends who use it).
- **Collaborative/shared albums:** let a group (a trip, an event) contribute photos into one shared
  combine — mirrors the "Groups" idea for Outlay, same underlying principle (shared object, multiple
  contributors, viral by construction) applied to a photo context instead of a financial one.

## 4. A genuine cross-app synergy (not forced)

Stitchify combines multiple images into one continuous image; Outlay scans receipts. Long
thermal-register receipts are commonly photographed in multiple pieces — "combine your receipt
photos into one image, then scan it into Outlay" is a real, non-contrived use case connecting both
products, not a stretch cross-promotion. Worth a small mention in Stitchify's marketing/UI
("scanning a long receipt? combine the pieces first") linking to Outlay, and vice versa in Outlay's
receipt-scanner flow if a user's photo looks partial/cut off.

## 5. Retention loops worth pairing with the above (brief — you asked "beyond marketing," these are
the product-side equivalent of marketing, i.e. what keeps people once invited)

- Budget-threshold push notifications ("you're at 90% of your Groceries budget") — bring users back
  at a moment the app is genuinely useful, not just to re-engage for its own sake.
- A weekly/monthly spending recap notification — passive re-engagement, low effort to build since
  the reports data already exists.
- Logging streaks (optional, some users find these motivating, others find them gimmicky — worth
  A/B testing rather than assuming).

## Suggested sequencing

1. Ship the referral program first — smallest lift, reuses existing infrastructure almost entirely.
2. Scope "Groups" as its own epic (resolve the `profiles` RLS bug first, since group-sharing RLS
   will build on the same foundation) — this is the biggest engineering investment here but also
   the biggest compounding payoff.
3. Bill-split as the lightweight entry point into Groups, with the web calculator as the
   no-install-required landing experience for invited non-users.
4. Stitchify's watermark mechanic in parallel — it's independent and cheap, no reason to sequence
   it after the Outlay work.

## Open questions for you

- Does Outlay's backend have any shared-access data model today, or would Groups be built from
  scratch? (Assumed from-scratch above — correct me if there's existing infra I'm not aware of.)
- Target incentive: free Pro days, or a different reward? Need this to size the `offers` table
  work against what's already planned for Promotional Offers.
- Want this filed in Jira as an epic (matching how [[prize_bond_app_idea]] was tracked) before any
  implementation starts?
