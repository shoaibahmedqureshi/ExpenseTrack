# Setting up the MAX subscriptions in the stores

The app already sells MAX: the paywall shows a Pro | MAX switch as soon as the store returns the MAX products.
Nothing in the app needs to change. The two products just have to exist, with exactly these IDs.

| | Product ID | Billing period |
|---|---|---|
| MAX Monthly | `expense_tracker_max_monthly` | 1 month |
| MAX Annual  | `expense_tracker_max_annual`  | 1 year |

Product IDs cannot be changed or reused after they are created, so check the spelling before saving.
Decide the prices first. Pro is $2.99 a month and $19.99 a year (44% saving on the annual plan); MAX should sit above that.

Names shown in the app come from the store (`product.title`). Suggested: "Outlay MAX Monthly" and "Outlay MAX Annual".
Suggested description: "Everything in Pro, plus family sharing for up to 10 people."

---

## 1. App Store Connect (iOS)

Prerequisite: the Paid Apps agreement is already active, because Pro sells today.

1. App Store Connect → your app → **Monetization → Subscriptions**.
2. Open the **same subscription group** that holds the Pro subscriptions. Putting MAX in the same group is what makes
   Pro → MAX an upgrade instead of a second subscription.
3. **Create** a subscription:
   - Reference name: `MAX Monthly`
   - Product ID: `expense_tracker_max_monthly`
   - Subscription duration: **1 Month**
   Repeat for `MAX Annual` / `expense_tracker_max_annual` with duration **1 Year**.
4. For each: **Subscription Prices → Add Subscription Price**. Choose the base country price and let Apple convert the rest.
5. For each: **Localization** → add display name and description (English at least).
6. **Rank the group** (Subscription group → *Subscription Ranking*, level 1 is the highest). Recommended order:
   1. MAX Annual
   2. MAX Monthly
   3. Pro Annual
   4. Pro Monthly
   Apple applies an **upgrade immediately** (prorated refund), and a **downgrade at the next renewal**. The app already
   shows a pending downgrade as "UPCOMING".
7. For each: **Review Information** → upload a screenshot of the paywall's MAX tab and a short note
   ("Sold from Profile → Upgrade, MAX tab").
8. Wait until each subscription says **Ready to Submit**. A product that is still "Missing Metadata" is not returned to the app,
   even in the sandbox.
9. First-time subscriptions are reviewed together with an app version. When you next submit a build, tick the two MAX
   subscriptions under that version's **In-App Purchases and Subscriptions** section.

Nothing to change for the server: App Store Server Notifications V2 already go to the existing webhook. Plain MAX purchases
(no offer code) are not recorded there, which is correct, since only influencer offers pay out.

### Testing on iOS
1. Users and Access → **Sandbox → Test Accounts** → create a tester.
2. On the phone: Settings → App Store → **Sandbox Account** → sign in with it.
3. Open the app → Profile → Upgrade. The **MAX** tab should now appear. Buy MAX Monthly.
4. Check: Profile says "MAX Plan", and the Family tab lets you create a family.
5. Buy Pro Monthly first, then MAX Annual, to test an upgrade. Then try going back to Pro: it should say it starts at the next renewal.

---

## 2. Google Play Console (Android)

1. Play Console → your app → **Monetize with Play → Products → Subscriptions → Create subscription**.
2. Product ID: `expense_tracker_max_monthly`, name "Outlay MAX Monthly". Save.
3. Inside it, **Add base plan**:
   - Base plan ID: for example `monthly` (any ID; the app uses the plain base plan)
   - Type: **Auto-renewing**, billing period **Monthly**
   - Price: set the base price and let Play convert the rest. Use **percentage-based** discounts only (never fixed
     amounts) if you add offers later, as already noted for influencer offers.
   - Grace period / account hold: set them the same as the Pro plans.
   **Activate** the base plan.
4. Repeat for `expense_tracker_max_annual` with a base plan of **Yearly**.
5. Match the structure of Pro: one subscription per product ID, one base plan each.
6. The new subscriptions only appear in the app on a build that is uploaded to a Play track (internal testing is enough) and
   installed from the Play Store by a licensed tester:
   - Setup → **License testing** → add the tester's Google account.
   - Upload a build to **Internal testing**, join the testing link on the phone, install from Play.
7. Voided-purchase notifications (refund handling): Monetize with Play → **Monetization setup → Real-time developer
   notifications** → the notification content must include **voided purchases**, not only subscriptions.

### Testing on Android
Same checks as iOS: the MAX tab appears, a purchase shows "MAX Plan", and the Family tab can create a family.
Do NOT test Pro → MAX on Android yet, see the warning below.

---

## 3. Changing plan on Android (built, needs a real-device test)

On Android, Pro and MAX are separate subscriptions. When a subscriber changes plan, the app now tells Google Play which
subscription is being replaced, so they never end up paying for two:

- **Up** (Pro Monthly → Pro Annual, Pro → MAX, MAX Monthly → MAX Annual): takes effect **immediately**; the unused time on
  the old plan is credited.
- **Down** (MAX → Pro, Annual → Monthly): takes effect **when the current paid period ends**. The app remembers the queued
  change and shows "Switching to …".
- The app first asks Google Play what the account really has. If Play cannot be reached, nothing is bought (no risk of a
  double subscription). If Play shows nothing active, the plan stored on the phone was out of date and the purchase goes
  ahead as a new one.

### Test on a real Android phone (licensed tester, internal testing build)
1. Buy **Pro Monthly**. Then buy **MAX Monthly** from the paywall's MAX tab. Play's purchase sheet should say it replaces your
   Pro subscription. Afterwards, Play Store → Payments & subscriptions → Subscriptions must list **only MAX**.
2. Switch **MAX → Pro**. The app should say the plan switches when the billing period ends. Play must still list MAX, now with
   Pro queued. (Test subscriptions renew every few minutes, so wait for the renewal and the plan will flip to Pro.)
3. Cancel everything, then buy MAX as a fresh user.

---

## 4. Going live checklist
- [ ] Prices decided
- [ ] iOS: both subscriptions **Ready to Submit**, ranked in the Pro group, ticked in the next app version
- [ ] Android: both subscriptions and base plans **Active**
- [ ] Sandbox purchase of MAX works on iOS; MAX tab visible
- [ ] Android: Pro → MAX leaves exactly one subscription in Play (section 3), and MAX → Pro waits for the period end
- [ ] Family tab creates a family after a MAX purchase
- [ ] Re-enable the real ML Kit package before the store build (see the project notes)
