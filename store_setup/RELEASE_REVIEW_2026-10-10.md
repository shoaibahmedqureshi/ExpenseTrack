# Release review of `feature/outlay-pro-v2` (2026-10-10)

## UPDATE (same day): corrections and what has been fixed

**Correction, more serious than first reported:** the live Supabase `service_role` key is ALSO public on `main` (in
`agents/profile-automation/.env`, `.env.example` and `.claude/settings.local.json`; identical to the current live key). The Gmail
password belongs to `outlay.noreply@gmail.com` (the same mailbox used for the agent BCC). On this local branch there is also a Supabase
secret key (`sb_secret_...`) in `.claude/settings.local.json` and `stitchify-approval-dashboard.html`, and the service-role key in
`setup-deployment.sh`. Deleting files does not remove them from git history. **These credentials must be rotated.**

Fixed in this branch and in production (items below refer to the numbers in section A/B):
- A3 done: RLS on and anon privileges revoked for `agent_logs`, `email_drafts`, `profile_links`, `seo_activity_log` (verified with the anon key).
- A4 done: the six back-office functions now require the service-role identity (no key: 401, anon key: 403, service key: allowed).
  `verify_jwt` is pinned in `supabase/config.toml`. NOTE: the scheduled GitHub workflows still work only if their secret holds the legacy
  service-role JWT.
- A5 done: `send_family_invitation` now mails only for a real, pending invitation the signed-in caller created, once an hour at most, with
  per-sender and per-address limits and an opt-out link; address and names come from the database.
- B7/B8/B9 done: version `1.2.0+52`; the debug build label is gone; Settings and Profile show the real version (a test keeps it in sync with pubspec).
- B11 done: the seven missing migrations and the `growth_agent` function are committed.
- Secrets removed from the working tree (not from history); `.env` files ignored; `.claude/settings.local.json` untracked.

Still open: rotate the credentials, decide about the daily workflows, privacy policy, MAX products, real-device tests, history clean-up
before the branch is pushed.

---

Branch: 63 commits ahead of `main`, 0 behind (a clean fast-forward). 387 files, about 74k lines added.
Checked on a clean checkout of the branch (real ML Kit): 376 tests pass; iOS release build (no code signing) succeeds, 84.6 MB.

## A. Security: fix before anything is pushed or released

1. **A Gmail password is in the PUBLIC repo already (on `main`).** `agents/profile-automation/.env`, `.env.example` and
   `DEPLOYMENT.md` contain it. The repository `shoaibahmedqureshi/ExpenseTrack` is public. Change that Gmail password now (and any other
   place it is used), then delete those files from the repo. Changing the password matters more than deleting: it stays in git history.
2. **The production Supabase `service_role` key is in `setup-deployment.sh` on this branch** (added in commit 8196ac7, not on
   `main`). It has full database access. Do NOT push this branch as it is. Either remove the file from history, or merge to `main` with a
   squash from a local branch and never push the feature branch. Rotate the service-role key afterwards if there is any chance it left your
   machine (for example the script ran `gh secret set` with it).
3. **Four tables are open to the internet:** `agent_logs`, `email_drafts` (68 rows of outreach drafts), `profile_links`,
   `seo_activity_log` have Row Level Security OFF and full privileges for `anon`, including TRUNCATE. The anon key ships inside the app, so
   anyone can read, change or wipe them. Fix: enable RLS and revoke access from `anon` and `authenticated` (the agents use the service role).
4. **Agent functions can be triggered by anyone.** `influencer_agent` and `seo_aso_agent` have JWT checking off and do no authentication, so
   anyone on the internet can make them call the Claude API (your cost) and write to the database. `agent_approval_handler`,
   `send_approved_emails`, `growth_agent` and `test_email_send` accept any valid JWT, and the public anon key is one. Outreach email is locked
   off, so nothing is sent today, but approving drafts and sending would be reachable if it were ever switched on. Fix: require a secret header
   (or the service-role bearer the GitHub workflow already sends), or turn the functions off until the agents are needed.
5. **`send_family_invitation` is an open email relay.** It sends an email from contact@outlayapp.net to any address in the request, with
   attacker-chosen name and family text, to anyone holding a JWT (the anon key counts). It needs the same checks as the group invitation
   emails: the caller must be the family admin, the invitation must exist, plus limits and an opt-out.
6. **GitHub Actions run the agents daily on the public repo** (`run-agents.yml` at 06:00 and 08:00 UTC, `run-profile-agent.yml` at
   06:00 UTC). They have been running; the profile agent run on 2026-10-09 hung for 6 hours and was cancelled. Decide whether you want
   them. If not, disable the workflows.

## B. Must fix before release (app)

7. **Version is unchanged: `1.1.0+51`**, identical to production. Bump it (for example `1.2.0+52`).
8. **Debug label shown to users:** `AppConstants.buildLabel = 'build-2026-08-13-PRODUCTION-real-purchase-test'` appears at the bottom of the
   Profile screen. Remove it.
9. **Settings shows "Version 1.0.0"** (hard-coded). Read the real version from the package info.
10. **ML Kit** must be restored for the store build. The simulator workaround (commented pubspec line, `mlkit_shim.dart`, two scanner files,
    `pubspec.lock`, `Podfile.lock`) is uncommitted and must never be committed. The committed state already uses the real package; do release
    builds from a clean checkout (verified: it builds).
11. **Seven migrations are missing from git** but applied to production: `20260929000000` (influencer_revenue), `20260929000002`,
    `20260929000003`, `20260930000004`, `20260930000005`, `20260930000006`, `20261001000000`. A migration that is committed
    (`20261014000000_lock_influencer_revenue`) depends on one of them, so replaying the committed migrations on a fresh database fails.
    Commit them.
12. **MAX is not for sale yet:** the two store products must be created and priced (`store_setup/MAX_SUBSCRIPTIONS.md`), and the Android
    upgrade path needs a real-device test.
13. **Production database is ahead of the shipped app.** The changes are additive and the shipped v1.1.0+51 does not use the changed
    tables (checked), but run the quick check: sign in, add an expense, sync, on the live app.
14. **Privacy policy is out of date** (last updated June 29, 2026; no mention of families, sharing monthly totals, split groups or
    invitation emails). Update `docs/privacy.html`, and the App Store privacy answers and Google Play data-safety form.

## C. Should fix (not blocking)

15. `agent_dashboard_screen.dart` has 4 analyzer errors and nothing uses it. Delete it (a stray import would break the build).
16. New dependencies `file_picker` and `pdfx`; `pdfx` is not used anywhere. Remove it (app size, App Review questions).
17. Clutter: about 20 loose files in the repo root (`AGENT*.md`, `DEPLOYMENT*.md/.txt`, `deploy.sh`, `test_agents.sh`, `EXECUTE_THIS.sql`...), plus the
    `agents/` folder. `.env.local` is untracked, which is correct; keep it out of git.
18. `.claude/settings.local.json` is tracked although it is in `.gitignore`. Untrack it.
19. 115 deprecation notices (`withOpacity` and similar) and 18 "BuildContext after await" notices. Not urgent.
20. `subscription_management_screen.dart` is unused and shows placeholder prices.
21. `growth_agent` function is untracked in git.
22. No translations were added for the new screens (Family, Splits groups, Household, Growth).

## D. Verified OK
- Clean fast-forward merge into `main`. No other changes on `main`.
- 376 tests pass; no analyzer errors in code that is compiled into the app.
- All 39 migrations are applied to production; none pending.
- Row Level Security is on for every table created in this work, tested by impersonating users. Public email endpoints are rate limited and
  have opt-outs; store webhooks verify the store's signature.
- iOS release build compiles with the real ML Kit.
- Secrets in the repo that are fine: the Supabase anon key in the creator portal config (public by design).

## Suggested order
1. Rotate the Gmail password; decide about the daily workflows; delete the leaked files.
2. Fix A3, A4, A5 (database and functions; no app release needed).
3. Remove `setup-deployment.sh` and the `agents/` folder from the branch (and from history if the branch will be pushed).
4. Commit the seven migrations; remove clutter; bump the version; remove the debug label.
5. Create the MAX products; test on a real iPhone and Android phone.
6. Update the privacy policy and store forms.
7. Squash-merge to `main`, tag, build from a clean checkout, submit.
