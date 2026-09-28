# Phase 2: MAX Subscription & Family Accounts — Quick Reference

**Status:** In Progress  
**Date Started:** September 28, 2026  
**Target Completion:** October 12, 2026 (2 weeks)

---

## What's Being Built

### Tier 3: MAX (₨599/month)
- **Family Accounts:** 5-10 multi-user members with role-based access
- **Unlimited Accounts:** No 3-account limit (vs Pro's 3-account limit)
- **Influencer Dashboard:** Track revenue attribution & performance
- **Priority Support:** 24-hour response
- **Advanced Analytics:** Family-level insights

### Key Differentiator
**No competitor offers family accounts + expense splits + SMS auto-logging.** This is Outlay's unique market position.

---

## Implementation Phases

### Phase 2a: Subscription Infrastructure (This Week)
1. ✅ Add `max` plan to `SubscriptionPlan` enum
2. ✅ Add Max product IDs (kMaxMonthlyId, kMaxAnnualId)
3. ✅ Update paywall to show 3-tier pricing
4. ✅ Extend SubscriptionStatus to track family membership
5. ✅ Create database schema for family_groups table

### Phase 2b: Family Accounts Core (Week 2)
1. 🔲 Create family group domain entities
2. 🔲 Create family_members table with roles
3. 🔲 Implement RLS policies for family access
4. 🔲 Create FamilyGroupProvider for state management
5. 🔲 Build family repository & repository impl

### Phase 2c: Family Management UI (Week 2-3)
1. 🔲 Family settings screen
2. 🔲 Create family group flow
3. 🔲 Invite members (email/SMS)
4. 🔲 Accept/reject invitations
5. 🔲 Manage roles & permissions
6. 🔲 Leave family account

### Phase 2d: Influencer Dashboard (Week 3)
1. 🔲 Create influencer_revenue table
2. 🔲 Track subscription → influencer attribution
3. 🔲 Revenue dashboard screen
4. 🔲 Performance analytics charts

---

## Files to Create

### Subscription Updates
- `lib/features/subscription/domain/subscription_status.dart` (extend)
- `lib/features/subscription/data/subscription_service.dart` (extend)
- `lib/features/subscription/presentation/screens/paywall_screen.dart` (extend)

### Family Accounts — Domain Layer
- `lib/features/family_accounts/domain/entities/family_group.dart`
- `lib/features/family_accounts/domain/entities/family_member.dart`
- `lib/features/family_accounts/domain/entities/family_invitation.dart`
- `lib/features/family_accounts/domain/repositories/family_repository.dart`

### Family Accounts — Data Layer
- `lib/features/family_accounts/data/models/family_group_model.dart`
- `lib/features/family_accounts/data/models/family_member_model.dart`
- `lib/features/family_accounts/data/repositories/family_repository_impl.dart`

### Family Accounts — Presentation Layer
- `lib/features/family_accounts/presentation/providers/family_provider.dart`
- `lib/features/family_accounts/presentation/screens/family_settings_screen.dart`
- `lib/features/family_accounts/presentation/screens/create_family_screen.dart`
- `lib/features/family_accounts/presentation/screens/invite_members_screen.dart`
- `lib/features/family_accounts/presentation/screens/family_members_list_screen.dart`

### Influencer Dashboard
- `lib/features/influencer_dashboard/domain/entities/influencer_revenue.dart`
- `lib/features/influencer_dashboard/presentation/screens/influencer_dashboard_screen.dart`

### Database Schema
- `supabase/schema.sql` (add family_groups, family_members, family_invitations, influencer_revenue tables)

---

## Database Schema (Supabase)

### family_groups table
```sql
CREATE TABLE family_groups (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,  -- creator
  name TEXT NOT NULL,
  description TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);
-- RLS: users can only see families they're a member of
```

### family_members table
```sql
CREATE TABLE family_members (
  id BIGSERIAL PRIMARY KEY,
  family_id BIGINT REFERENCES family_groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT CHECK (role IN ('admin', 'member', 'viewer')),
  joined_at TIMESTAMP DEFAULT now()
);
-- RLS: members can only manage their own families
```

### family_invitations table
```sql
CREATE TABLE family_invitations (
  id BIGSERIAL PRIMARY KEY,
  family_id BIGINT REFERENCES family_groups(id) ON DELETE CASCADE,
  invited_email TEXT NOT NULL,
  invited_by UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT CHECK (role IN ('member', 'viewer')),
  status TEXT CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at TIMESTAMP DEFAULT now(),
  expires_at TIMESTAMP DEFAULT now() + INTERVAL '7 days'
);
```

### influencer_revenue table
```sql
CREATE TABLE influencer_revenue (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  family_id BIGINT REFERENCES family_groups(id) ON DELETE SET NULL,
  influencer_code TEXT NOT NULL,
  subscription_plan TEXT,  -- max, pro_monthly, pro_annual
  revenue_amount NUMERIC(10,2),
  currency TEXT DEFAULT 'PKR',
  transaction_date TIMESTAMP DEFAULT now()
);
```

---

## Feature Breakdown

### MAX Subscription Features

#### 1. Family Accounts (5-10 members)
- **Admin:** Full access (add members, change settings)
- **Member:** Can log expenses, view family dashboard
- **Viewer:** Read-only access (insights only)

#### 2. Unlimited Accounts
- No 3-account limit (Pro has 3-account limit)
- Shared family budget pool
- Per-account vs family-wide balance visibility

#### 3. Influencer Revenue Dashboard
- Track which influencers drove subscriptions
- Revenue attribution by influencer code
- Performance metrics (conversion, LTV)
- Payout tracking

#### 4. Advanced Analytics
- Family spending trends
- Per-member contribution breakdown
- Category-wise family spend
- Recurring vs one-time spend

---

## Testing Checklist

### Subscription Tier Tests
- [ ] Free user can see all 3 tiers in paywall
- [ ] Pro user can upgrade to Max
- [ ] Max user can see unlimited accounts option
- [ ] Annual Max discount (17% off) displays correctly

### Family Accounts Tests
- [ ] Create family group as Max user
- [ ] Invite members via email (generates invitation link)
- [ ] Invited user accepts invitation
- [ ] Admin can change member roles (member ↔ viewer)
- [ ] Admin can remove members
- [ ] Member can view family dashboard
- [ ] Viewer can only view (no add/edit)
- [ ] Family dashboard shows all members' expenses
- [ ] Real-time sync across family members' devices

### Influencer Dashboard Tests
- [ ] Influencer code resolves to correct revenue entry
- [ ] Dashboard shows revenue by code
- [ ] Payout calculations are correct
- [ ] Charts render for performance metrics

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Pro → Max upgrade conversion | 5-10% |
| Family adoption (from Max users) | 50%+ |
| Average family size | 3-4 members |
| Member retention (30 days) | 75%+ |
| Influencer attribution accuracy | 98%+ |

---

## Next Steps

1. ✅ Review pricing strategy & features
2. → Add Max tier to subscription infrastructure
3. → Create family account domain entities
4. → Build family account database schema
5. → Implement family management UI
6. → Test end-to-end flows
7. → Deploy MAX tier to production

---

**Phase 2a Focus:** Subscription infrastructure + database schema (this session)
