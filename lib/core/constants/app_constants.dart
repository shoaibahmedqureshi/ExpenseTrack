class AppConstants {
  AppConstants._();

  static const String appName = 'Outlay';

  // Numeric Apple App ID (not the bundle ID) — from App Store Connect's
  // App Information page. Needed to build the direct offer-code redemption
  // URL (apps.apple.com/redeem?ctx=offercodes&id=...&code=...); left blank
  // until Shoaib provides it.
  static const String appleAppStoreId = '6790199113';

  // Bumped by hand on every release build made for device testing, so a
  // tester can confirm — via the Profile screen — which exact build is
  // actually installed, instead of assuming a fresh APK replaced an old
  // one. The Android versionCode in pubspec.yaml is bumped alongside this
  // for the same reason at the OS level.
  static const String buildLabel = 'build-2026-08-13-PRODUCTION-real-purchase-test';

  static const String dbName = 'expense_tracker.db';
  static const int dbVersion = 7; // v3 adds budgets table, v4 adds soft-delete, v5 updates default category colors, v6 adds expenses.tax, v7 adds user_id to every table (cross-account data isolation)

  // SharedPreferences keys
  static const String prefOnboardingDone = 'onboarding_done';

  // Table names
  static const String expensesTable = 'expenses';
  static const String categoriesTable = 'categories';
  static const String budgetsTable = 'budgets';
}
