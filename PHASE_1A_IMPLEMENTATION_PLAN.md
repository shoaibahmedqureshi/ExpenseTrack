# Phase 1a Implementation Plan - Outlay Pro

**Timeline**: Weeks 1-2  
**Status**: Starting  
**Branch**: feature/outlay-pro-v2

---

## 🎯 Phase 1a Goals

1. ✅ SMS Auto-Logging screen with bank SMS parsing configuration
2. ✅ Enhanced Dashboard with account cards and recurring section
3. ✅ 5-tab bottom navigation (Dashboard, Accounts, Splits, Family, Settings)

---

## 📋 Implementation Breakdown

### Task 1: Navigation Structure (Foundation)
**Current**: 4 tabs (Dashboard, Transactions, Budgets, Reports)  
**Target**: 5 tabs (Dashboard, Accounts, Splits, Family, Settings)

**Changes**:
- [ ] Update `lib/core/widgets/main_shell.dart`:
  - Modify `_tabLabels` to: `['Dashboard', 'Accounts', 'Splits', 'Family', 'Settings']`
  - Modify `_tabIcons` to: `[Icons.home_outlined, Icons.account_balance_wallet, Icons.people_outline, Icons.group_outlined, Icons.settings_outlined]`
  - Add new screens to IndexedStack (5 screens total)

**Files to modify**:
- `lib/core/widgets/main_shell.dart`

**Blocked By**: None  
**Estimate**: 30 minutes

---

### Task 2: Create SMS Auto-Logging Feature
**Target**: Full SMS parsing screen with bank configuration

**Structure**:
```
lib/features/sms_auto_logging/
├── data/
│   ├── models/
│   │   ├── sms_bank.dart          # Bank SMS configuration
│   │   └── sms_parsed_transaction.dart
│   ├── datasources/
│   │   └── sms_datasource.dart
│   └── repositories/
│       └── sms_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── sms_bank.dart
│   │   └── parsed_transaction.dart
│   ├── repositories/
│   │   └── sms_repository.dart
│   └── usecases/
│       ├── parse_sms_usecase.dart
│       └── get_active_banks_usecase.dart
└── presentation/
    ├── providers/
    │   └── sms_provider.dart       # State management
    └── screens/
        └── sms_auto_logging_screen.dart
```

**Key Features**:
1. SMS Permission Status Toggle
   - Check if SMS READ permission is granted
   - Toggle to enable/disable SMS parsing
   - Show security note

2. Active Banks Grid
   - Show 6 banks: HBL, UBL, MCB, Meezan, Faysal, JazzCash
   - Status indicator (green checkmark = SMS detected, gray = waiting)
   - Transaction count per bank

3. Weekly Statistics
   - "Captured This Week" count
   - "Time Saved" calculation
   - Detection Accuracy progress bar (target 98%+)

4. Recent SMS Transactions List
   - Scrollable list of parsed transactions
   - Bank icon, amount, category, "Added Xh ago"
   - Swipe actions (edit, delete)

**Files to create**:
- SMS feature structure (10+ files as listed above)
- Main screen: `sms_auto_logging_screen.dart`

**Dependencies**:
- Permission handler (already in pubspec)
- Flutter SMS receiver or similar

**Estimate**: 4-6 hours

---

### Task 3: Enhance Dashboard Screen
**Target**: Add account cards row + recurring section

**Changes to `lib/features/dashboard/presentation/screens/dashboard_screen.dart`**:

1. Add Account Cards Section (after balance card)
   - Horizontally scrollable row
   - Card for each account (HBL Checking, Meezan Savings, etc.)
   - Show account balance + sparkline + sync status

2. Add Recurring Transactions Section
   - Title: "Recurring This Month"
   - Display total (₨5,000)
   - Breakdown: Bills (₨3,000), Subscriptions (₨2,000)

3. Keep existing sections
   - Top balance card
   - Recent transactions
   - Budget wheel (if applicable)

**UI Components**:
- Account card widget (reusable)
- Sparkline chart (simple trend line)
- Recurring summary card

**Mock Data** (for now):
```dart
final accounts = [
  {'name': 'HBL Checking', 'balance': 64200, 'icon': Icons.account_balance},
  {'name': 'Meezan Savings', 'balance': 35000, 'icon': Icons.savings},
  // ... more
];
```

**Files to modify**:
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

**Files to create**:
- `lib/features/dashboard/presentation/widgets/account_card.dart`
- `lib/features/dashboard/presentation/widgets/recurring_section.dart`

**Estimate**: 2-3 hours

---

### Task 4: Create Placeholder Screens
**Target**: Create basic screens for new tabs (will be fleshed out in Phase 1b)

**Accounts Screen**:
- Placeholder or MVP account list
- "+ Add Account" button
- Link to Multi-Account Management (Phase 1b)

**Splits Screen**:
- Placeholder: "Coming Soon" or basic event list
- Link to Event Splits (Phase 2)

**Family Screen**:
- Placeholder: "Coming Soon"
- Link to Family Accounts (Phase 2 - Max tier only)

**Settings Screen**:
- Placeholder: Basic settings options
- Language selection
- Theme toggle
- About section

**Files to create**:
- `lib/features/accounts/presentation/screens/accounts_screen.dart`
- `lib/features/splits/presentation/screens/splits_screen.dart`
- `lib/features/family/presentation/screens/family_screen.dart`
- `lib/features/settings/presentation/screens/settings_screen.dart`

**Estimate**: 1-2 hours

---

## 🔄 Implementation Order

1. **Task 1** (Navigation) - 30 min → unblocks all others
2. **Task 4** (Placeholder Screens) - 1-2 hours → allows testing navigation
3. **Task 3** (Dashboard Enhancement) - 2-3 hours → visual progress
4. **Task 2** (SMS Feature) - 4-6 hours → main feature

**Total Timeline**: ~10-13 hours = ~1-2 days (2 devs) or 2-3 days (1 dev)

---

## 🛠️ Technical Stack

- **Framework**: Flutter
- **State Management**: Provider
- **Local DB**: SQLite (existing)
- **Remote DB**: Supabase
- **SMS Handling**: [TBD - research: flutter_sms, telephony, or native platform channels]

---

## 📦 Dependencies to Add (if needed)

```yaml
# pubspec.yaml additions
dependencies:
  permission_handler: ^11.0.0  # Already present?
  fl_chart: ^0.68.0  # For sparklines/charts
  # Check if needed:
  # - flutter_sms (SMS reading)
  # - telephony (SMS on Android)
```

---

## ✅ Definition of Done (Phase 1a)

- [ ] 5-tab navigation working (all tabs switch correctly)
- [ ] SMS Auto-Logging screen displays with mock data
- [ ] Dashboard shows account cards + recurring section
- [ ] All placeholder screens exist and navigate properly
- [ ] No console errors
- [ ] Basic responsive layout (mobile-first)
- [ ] Colors match existing Outlay theme
- [ ] All screens tested on iOS simulator

---

## 📝 Notes

1. **Use existing Outlay colors** — don't adopt Stitch palette (keeping consistency)
2. **Keep designs as reference** — functionality first, visual polish later
3. **Mock SMS data** for now — real SMS parsing comes after permissions/channels setup
4. **Build incrementally** — get navigation + dashboard done, then SMS feature

---

## 🚀 Next Steps

1. Start with **Task 1** (Navigation refactor)
2. Verify 5 tabs render correctly
3. Move to **Task 4** (Placeholder screens)
4. Test navigation flow
5. Proceed to **Task 3** (Dashboard)
6. Finally **Task 2** (SMS feature)

---

**Branch**: feature/outlay-pro-v2  
**Ready to start**: 2026-09-26
