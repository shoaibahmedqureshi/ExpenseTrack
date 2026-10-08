# Outlay Creator Portal

Static site (no build step). Creators sign in with an email link, apply, and see their status and discount code.
Admins (rows in `app_admins`) sign in the same way, must pass an authenticator-app code, and then review applications.

Backend: `supabase/migrations/20261012000000_creator_portal.sql` (RPCs `submit_creator_application`, `my_creator_application`).

## Run locally
    cd portal && python3 -m http.server 8766   # open http://localhost:8766

## Before it can go live (dashboard settings, not in this repo)
1. **Auth > URL Configuration:** add the portal's URL to *Redirect URLs* (and localhost for testing).
2. **Auth > Email Templates > Magic Link:** point the link at the portal with a button-first flow so mail scanners
   cannot use it up, and include the code:
   `<a href="{{ .RedirectTo }}?token_hash={{ .TokenHash }}&type=email">Sign in</a>` and `Code: {{ .Token }}`
3. **Sending email:** Supabase's built-in sender is heavily rate-limited; add SendGrid SMTP under Auth > SMTP.
4. **Hosting:** upload this folder to Cloudflare Pages (direct upload, no merge to `main` needed) on its own subdomain, `creators.outlayapp.net`. Keep it out of `docs/`. `_headers` in this folder sets the security headers (frame blocking, referrer policy, CSP) and is picked up automatically.
5. Optional: enable the Google provider, then set `googleEnabled: true` in `config.js`.

## Notes
- `config.js` holds the public anon key only. Row-level security protects the data.
- The MFA requirement for admins is enforced by the portal. The database still treats any admin account as an admin
  at aal1 so the in-app Growth screen keeps working. To enforce it server side, add an `aal2` check to `is_app_admin()`
  once the app supports MFA.

## Marketing page
`docs/creators.html` is now a short landing page that links to `https://creators.outlayapp.net`. It also still shows the
banner for confirmation links sent by the older form (`?confirmed=1|0`). The older `creator_apply` / `creator_confirm`
edge functions are still deployed but nothing links to them any more.
