# Phase 1b Quick Reference Guide

## 🚀 What's New

### A. Live Accounts Dashboard
**Screen:** Dashboard → Account Cards (already visible)  
**Data:** Live from Supabase  
**Status:** ✅ Ready

```dart
// Load accounts on dashboard init
await context.read<AccountProvider>().loadAll();
```

---

### B. Receipt Scanner
**Screen:** `lib/features/scanner/presentation/screens/scanner_screen.dart`  
**Access:** Add to navigation bottom tabs  
**Features:**
- Camera capture or gallery pick
- OCR extraction (merchant, amount, tax)
- Confidence scoring
- Preview with edit capability

**Usage:**
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const ScannerScreen(),
));
```

**Data Extracted:**
- Merchant name
- Total amount
- Tax amount
- Line items (SKU, description, qty, price)
- Date
- Confidence score

---

### C. Tax Report Generator
**Screen:** `lib/features/reports/presentation/screens/tax_report_screen.dart`  
**Access:** Add to navigation or dashboard menu  
**Features:**
- Date range picker
- Configurable tax rate (0-50%)
- Category breakdown
- Multiple export formats (CSV, JSON, HTML)

**Usage:**
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const TaxReportScreen(),
));
```

**Key Inputs:**
```
From: Jan 1, 2025
To: Sep 28, 2026
Tax Rate: 15% (slider)
```

**Outputs:**
- Net Income = Total Income - Total Expenses
- Estimated Tax Liability = Net Income × Tax Rate
- Category-wise breakdown
- Export in CSV/JSON/HTML

---

### D. Bank Statement Import
**Screen:** `lib/features/import/presentation/screens/import_screen.dart`  
**Access:** Add to navigation or dashboard menu  
**Features:**
- CSV or PDF file picker
- 4 bank parsers (HBL, Meezan, MCB, Standard Chartered)
- Auto-detection of bank format
- Duplicate detection
- Transaction preview

**Usage:**
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const ImportScreen(),
));
```

**Supported Banks:**
```
HBL (Habib Bank Limited)        ✅ CSV & PDF
Meezan Bank                      ✅ CSV & PDF
MCB (Muslim Commercial Bank)     ✅ CSV & PDF
Standard Chartered Bank          ✅ CSV & PDF (multi-currency)
```

**Workflow:**
1. User selects CSV or PDF file
2. System detects bank automatically
3. Parses transactions
4. Checks for duplicates
5. Shows preview (can exclude flagged duplicates)
6. User confirms import

---

### E. Notifications Center
**Screen:** `lib/features/notifications/presentation/screens/notification_center_screen.dart`  
**Settings Screen:** `lib/features/notifications/presentation/screens/notification_settings_screen.dart`  
**Access:** Add to navigation bottom tabs  
**Features:**
- List all notifications
- Mark as read / dismiss
- Enable/disable alert types
- Unread badge counter

**Usage:**
```dart
// Show notification center
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const NotificationCenterScreen(),
));

// Show settings
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const NotificationSettingsScreen(),
));
```

**Alert Types:**
```
🔴 Budget Alert         — Triggers at 80% of budget
🔴 Low Balance Alert    — Triggers when balance < threshold
📅 Weekly Report        — Sunday summary (requires scheduler)
🎯 Goal Reached         — (Scaffolded for Phase 1c)
🔔 Recurring Reminder   — (Scaffolded for Phase 1c)
```

**Trigger Examples:**
```dart
// Check if budget alert should trigger
provider.checkBudgetAlert(
  spent: 800,     // PKR
  budget: 1000,   // PKR
);  // → Triggers notification (80%)

// Check if low balance alert should trigger
provider.checkLowBalance(
  balance: 500,   // PKR < 1000 threshold
);  // → Triggers notification
```

---

## 🔧 Integration Checklist

### Step 1: Update main.dart ✅
All providers already added:
- AccountProvider
- ScannerProvider
- ImportProvider
- TaxReportProvider
- NotificationProvider

### Step 2: Update Navigation
**File:** `lib/core/widgets/main_shell.dart` or dashboard navigation

```dart
// Add tabs to bottom nav
BottomNavigationBar(
  items: [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Scan'),
    BottomNavigationBarItem(icon: Icon(Icons.file_download), label: 'Import'),
    BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Tax'),
    BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
  ],
)
```

### Step 3: Add Database Seed
**File:** Run in Supabase SQL editor

```sql
-- Seed test accounts
INSERT INTO accounts (user_id, name, account_type, last_four, balance, icon_key, color, is_linked)
VALUES
  (auth.uid(), 'HBL Checking', 'checking', '4920', 64200, 'account_balance', '#667EEA', true),
  (auth.uid(), 'Meezan Savings', 'savings', '8812', 35000, 'savings', '#10B981', true),
  (auth.uid(), 'JazzCash', 'wallet', '1234', 15250, 'wallet', '#EF4444', true),
  (auth.uid(), 'Cash', 'cash', NULL, 11000, 'payments', '#F59E0B', false);
```

### Step 4: Verify Dependencies
**File:** `pubspec.yaml`

```yaml
dependencies:
  google_mlkit_text_recognition: ^0.5.0  # For scanner OCR
  pdfx: ^2.4.0                           # For bank import PDF
  file_picker: ^5.0.0                    # For file selection
  provider: ^6.0.0                       # State management ✅
  shared_preferences: ^2.0.0              # Notifications storage ✅
  intl: ^0.17.0                          # Formatting ✅
```

### Step 5: Test Locally
```bash
cd /Users/saloomi/Documents/Expense\ Tracker
flutter pub get
flutter run
```

---

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                    UI Layer                         │
├─────────────────────────────────────────────────────┤
│ Screens:                                            │
│  • AccountCard (Dashboard)                          │
│  • ScannerScreen + ReceiptPreviewScreen             │
│  • TaxReportScreen                                  │
│  • ImportScreen + ImportPreviewScreen               │
│  • NotificationCenterScreen + SettingsScreen        │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────┴──────────────────────────────────┐
│              Provider Layer (State)                 │
├─────────────────────────────────────────────────────┤
│  • AccountProvider        → CRUD accounts           │
│  • ScannerProvider        → Process receipts        │
│  • ImportProvider         → Parse statements        │
│  • TaxReportProvider      → Generate reports        │
│  • NotificationProvider   → Manage alerts           │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────┴──────────────────────────────────┐
│            Repository Layer (Data)                  │
├─────────────────────────────────────────────────────┤
│  • AccountRepository      → Supabase                │
│  • ScannerRepository      → MLKit + parser          │
│  • (Import has no repo)   → Direct parsing          │
│  • (Tax has no repo)      → Direct calculation      │
│  • NotificationRepository → SharedPreferences       │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────┴──────────────────────────────────┐
│           Data Source Layer (External)              │
├─────────────────────────────────────────────────────┤
│  • Supabase (accounts)                              │
│  • Google MLKit (OCR)                               │
│  • File system (CSV/PDF)                            │
│  • SharedPreferences (local notifications)          │
└─────────────────────────────────────────────────────┘
```

---

## 🧪 Manual Testing Workflow

### Test 1: Accounts
```
1. Seed 4 test accounts via SQL
2. Open app → Dashboard
3. See 4 account cards with live balances
4. Verify colors and icons match
5. ✅ Pass
```

### Test 2: Receipt Scanner
```
1. Navigate to Scanner
2. Take photo of receipt (or use gallery)
3. See OCR results (merchant, amount, tax)
4. Verify accuracy (check receipt physically)
5. ✅ Pass if >85% accurate
```

### Test 3: Tax Export
```
1. Navigate to Tax Report
2. Set date range (last 30 days)
3. Adjust tax rate to 20%
4. Click "Generate Report"
5. See category breakdown
6. Click "Download CSV"
7. Open file → verify format and calculations
8. ✅ Pass
```

### Test 4: Bank Import
```
1. Navigate to Import
2. Download HBL statement CSV from bank
3. Click "Select CSV or PDF"
4. Select file → see preview
5. Check for duplicate detection
6. Confirm import
7. ✅ Pass if transactions appear
```

### Test 5: Notifications
```
1. Navigate to Notifications Settings
2. Enable "Budget Alert"
3. Go to Dashboard → add expense >80% of budget
4. Return to Notifications → see alert
5. Click notification → marked as read
6. Click "Dismiss" → removed from center
7. ✅ Pass
```

---

## 📝 Common Tasks

### Add Tax Report to Dashboard Menu
```dart
// In dashboard_screen.dart
FloatingActionButton(
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const TaxReportScreen()),
  ),
  tooltip: 'Generate Tax Report',
  child: const Icon(Icons.assessment),
)
```

### Trigger Notification from Expense Creation
```dart
// In expense_screen.dart after expense is created
final notificationProvider = context.read<NotificationProvider>();
await notificationProvider.loadRules();
notificationProvider.checkBudgetAlert(totalSpent, budgetLimit);
```

### Get Unread Notification Count
```dart
int unreadCount = context.watch<NotificationProvider>().unreadCount;
// Show in app bar badge or bottom nav
```

### Export Report File (Future Enhancement)
```dart
// Currently just shows content in dialog
// To implement: use share_plus or file_saver package
import 'package:share_plus/share_plus.dart';

final csv = provider.exportCsv();
await Share.shareXFiles([file], text: 'Tax Report');
```

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| Scanner OCR not working | Verify google_mlkit_text_recognition in pubspec.yaml |
| PDF import fails | Ensure pdfx dependency is added |
| Accounts not loading | Seed test data via SQL, verify Supabase connection |
| Notifications not showing | Check SharedPreferences data, verify provider initialized |
| Tax rate persists after restart | Tax rate is session-only; will be fixed in Phase 1c |
| Duplicate detection too strict | Adjust thresholds in DuplicateDetector (dayThreshold, amountThreshold) |

---

## 📚 File Organization

```
lib/features/
├── accounts/
│   ├── domain/entities/account.dart
│   ├── domain/repositories/account_repository.dart
│   ├── data/models/account_model.dart
│   ├── data/repositories/account_repository_impl.dart
│   └── presentation/providers/account_provider.dart
│
├── scanner/
│   ├── domain/entities/scanned_receipt.dart
│   ├── domain/repositories/scanner_repository.dart
│   ├── data/repositories/scanner_repository_impl.dart
│   ├── data/services/receipt_parser_service.dart
│   └── presentation/
│       ├── providers/scanner_provider.dart
│       └── screens/
│           ├── scanner_screen.dart
│           ├── image_picker_service.dart
│           └── receipt_preview_screen.dart
│
├── reports/
│   ├── domain/entities/tax_report.dart
│   ├── data/services/tax_export_service.dart
│   └── presentation/
│       ├── providers/tax_report_provider.dart
│       └── screens/tax_report_screen.dart
│
├── import/
│   ├── domain/entities/bank_statement.dart
│   ├── data/services/
│   │   ├── bank_parsers/
│   │   │   ├── hbl_parser.dart
│   │   │   ├── meezan_parser.dart
│   │   │   ├── mcb_parser.dart
│   │   │   └── standard_chartered_parser.dart
│   │   ├── bank_format_detector.dart
│   │   ├── pdf_parser_service.dart
│   │   └── duplicate_detector.dart
│   └── presentation/
│       ├── providers/import_provider.dart
│       └── screens/
│           ├── import_screen.dart
│           └── import_preview_screen.dart
│
└── notifications/
    ├── domain/
    │   ├── entities/notification.dart
    │   └── repositories/notification_repository.dart
    ├── data/repositories/notification_repository_impl.dart
    └── presentation/
        ├── providers/notification_provider.dart
        └── screens/
            ├── notification_center_screen.dart
            └── notification_settings_screen.dart
```

---

**Last Updated:** September 28, 2026  
**Phase:** 1b Complete  
**Status:** Ready for Testing
