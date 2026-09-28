# Phase 3a: Test & Verification Guide

**Status:** Ready for Testing  
**Date:** September 28, 2026  
**Components:** All navigation integrated, ready for E2E verification

---

## Pre-Test Checklist

✅ All 8 new files created  
✅ InfluencerProvider integrated into main.dart  
✅ Settings navigation added  
✅ Dashboard → Details navigation working  
✅ Repository & Supabase integration complete  
✅ Provider state management ready  

---

## Test Flow 1: Settings Navigation

**Objective:** Verify navigation from Settings → Influencer Dashboard

**Steps:**
1. Launch app and authenticate
2. Tap **Settings** tab (bottom nav)
3. Scroll to **Influencer** section
4. Tap **Revenue Dashboard**
5. Verify: Dashboard screen loads without errors

**Expected Result:** ✅ InfluencerDashboardScreen displays with:
- AppBar: "Influencer Revenue"
- Period selector buttons (All Time / This Year / This Month)
- Empty state message (if no revenue data)
- No console errors

**If Failed:**
- Check imports in settings_screen.dart
- Verify InfluencerDashboardScreen exists at path
- Check Flutter build logs

---

## Test Flow 2: Dashboard Load & Display

**Objective:** Verify dashboard metrics calculation & UI rendering

**Prerequisites:** 
- User is authenticated
- Supabase is connected
- (Optional) Revenue data exists in DB

**Steps:**
1. Navigate to Influencer Dashboard
2. Wait for provider to load data
3. Verify UI renders:
   - [ ] Summary card (Total Revenue, etc.)
   - [ ] 3 metric cards (Monthly, Yearly, Conversions)
   - [ ] Average per conversion calculated
   - [ ] Top codes list displayed (if data exists)

**Expected UI:**
```
┌─────────────────────────────────┐
│ Influencer Revenue      ☰        │
├─────────────────────────────────┤
│ [All Time] [This Year] [Month]  │
│                                  │
│ Total Revenue: PKR 0.00          │
│ ┌──────────────┬──────────────┐  │
│ │ This Month   │ This Year    │  │
│ │ PKR 0.00     │ PKR 0.00     │  │
│ └──────────────┴──────────────┘  │
│ ┌──────────────┬──────────────┐  │
│ │ Conversions  │ Avg/Conv     │  │
│ │ 0            │ PKR 0.00     │  │
│ └──────────────┴──────────────┘  │
│                                  │
│ No revenue data available...     │
└─────────────────────────────────┘
```

**If Empty:**
- This is expected if no revenue records in DB
- Proceed to Test Flow 3 for data creation

---

## Test Flow 3: Create Test Revenue (With DB Access)

**Objective:** Test revenue tracking & aggregation

**Prerequisites:** Supabase access

**Steps:**
1. Insert test revenue records into `influencer_revenue` table:
   ```sql
   INSERT INTO influencer_revenue 
   (user_id, influencer_code, subscription_plan, revenue_amount, 
    currency, transaction_date)
   VALUES
   ('current-user-id', 'CODE123', 'proMonthly', 999.00, 'PKR', now()),
   ('current-user-id', 'CODE123', 'proAnnual', 5000.00, 'PKR', now()),
   ('current-user-id', 'CODE456', 'maxMonthly', 1500.00, 'PKR', now());
   ```

2. Return to Dashboard (or refresh/reload)
3. Verify dashboard now shows:
   - Total Revenue: 7,499.00
   - Conversions: 3
   - Top codes: CODE123, CODE456

**Expected Behavior:**
- Provider loads data automatically
- Calculations are accurate
- UI updates in real-time

---

## Test Flow 4: Period Filtering

**Objective:** Verify date range filtering works

**Prerequisites:** Test revenue from Flow 3

**Steps:**
1. On dashboard, tap **This Month** period button
2. Verify:
   - [ ] Button highlights in blue
   - [ ] Data refreshes
   - [ ] Dashboard shows month-to-date revenue
3. Tap **This Year** → verify yearly totals
4. Tap **All Time** → verify all-time totals

**Expected Result:**
- Period filtering works correctly
- Metrics update based on selected period
- Button highlighting provides visual feedback

---

## Test Flow 5: Code Details Navigation

**Objective:** Test tap-to-details navigation

**Prerequisites:** Test revenue from Flow 3 with CODE123 at top

**Steps:**
1. On dashboard, locate top codes list
2. Tap on **CODE123** card
3. Verify RevenueDetailsScreen loads:
   - [ ] AppBar: "CODE123 Revenue"
   - [ ] Total revenue displayed
   - [ ] Conversions count shown
   - [ ] Subscription plan breakdown shown
   - [ ] Transaction list displays all CODE123 records

**Expected UI:**
```
┌─────────────────────────────────┐
│ CODE123 Revenue         ☰        │
├─────────────────────────────────┤
│ Total Revenue: PKR 6,000.00      │
│ Conversions: 2                   │
│                                  │
│ Conversions by Plan             │
│ proMonthly        [1]            │
│ proAnnual         [1]            │
│                                  │
│ Recent Transactions             │
│ proMonthly  2026-09-28 PKR 999   │
│ proAnnual   2026-09-28 PKR 5000  │
│                                  │
│ [EXPORT DATA]                    │
└─────────────────────────────────┘
```

**If Failed:**
- Check RevenueDetailsScreen initialization
- Verify loadCodeRevenues() is called
- Check Supabase filtering logic

---

## Test Flow 6: Back Navigation

**Objective:** Verify back button and navigation stack

**Steps:**
1. From Code Details screen, tap **Back** (Android back button or iOS back gesture)
2. Verify: Returns to Dashboard
3. From Dashboard, tap **Settings** tab
4. Verify: Navigation works correctly

**Expected Result:**
- Navigation stack maintained properly
- State not lost on back navigation

---

## Test Flow 7: Error Handling

**Objective:** Verify graceful error states

**Prerequisites:** (Simulate error by disconnecting network or stopping Supabase)

**Steps:**
1. Open Dashboard
2. Simulate network disconnection (Airplane mode or unplug internet)
3. Try to refresh/reload
4. Verify: Error screen displays gracefully

**Expected Error UI:**
```
┌─────────────────────────────────┐
│                                  │
│  ⚠️  Error Loading Revenue        │
│                                  │
│  Connection refused...           │
│                                  │
└─────────────────────────────────┘
```

**Expected Behavior:**
- Error message readable and user-friendly
- No console errors or crashes
- Allows retry after reconnection

---

## Test Flow 8: Loading States

**Objective:** Verify loading indicators display correctly

**Steps:**
1. Open Dashboard
2. Observe initial load (should be quick but watch for spinner)
3. Verify: CircularProgressIndicator shown during load

**Expected Result:**
- Loading spinner appears briefly while data loads
- Smooth transition to content
- No janky transitions

---

## Performance Checklist

| Test | Target | Status |
|------|--------|--------|
| Dashboard load time | < 2s | 🔄 Test |
| Metrics calculation | < 500ms | 🔄 Test |
| Details screen load | < 1s | 🔄 Test |
| Scroll 100+ records | Smooth | 🔄 Test |

**Performance Testing Steps:**
1. Enable DevTools Performance overlay (Flutter)
2. Open Dashboard with 100+ revenue records
3. Monitor:
   - Frame rate (should be 60fps)
   - Memory usage (should be < 50MB increase)
   - CPU usage (should be < 30%)

---

## Known Limitations (Not Tested Here)

- [ ] PDF export (UI ready, functionality deferred)
- [ ] Real-time updates (manual refresh required)
- [ ] Charts/visualization (not implemented yet)

---

## Success Criteria

**Phase 3a Complete When:**

✅ All 8 tests pass without errors  
✅ Navigation flows smoothly  
✅ Data loads and displays correctly  
✅ Error states show gracefully  
✅ Performance acceptable  
✅ No console warnings/errors  

---

## Troubleshooting

### App Won't Build
```
flutter clean
flutter pub get
flutter run
```

### Import Errors
- Check file paths in imports
- Verify all 8 files exist in correct directories
- Run: `flutter analyze`

### Provider Not Found
- Verify InfluencerProvider added to main.dart MultiProvider
- Check SupabaseClient is passed correctly

### No Data Displays
- Check Supabase credentials in SupabaseConfig
- Verify user is authenticated
- Insert test revenue via Supabase console

### Navigation Not Working
- Check Navigator.push syntax matches settings_screen.dart
- Verify screen class names match imports

---

## Next Steps After Testing

1. **If All Tests Pass:**
   - Phase 3a is complete ✅
   - Ready to start Phase 3b (Family Analytics)

2. **If Issues Found:**
   - Document specific failure
   - Check error logs
   - Fix root cause
   - Re-run failing test

3. **Enhancement Opportunities:**
   - Add PDF export functionality
   - Implement real-time Supabase subscriptions
   - Add charts for trend visualization

---

**Test Conducted By:** [Your Name]  
**Date Tested:** [Date]  
**Results:** [ ] All Pass [ ] Some Failures
