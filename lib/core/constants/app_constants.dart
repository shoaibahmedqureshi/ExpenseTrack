class AppConstants {
  AppConstants._();

  static const String appName = 'Outlay';

  // Bumped by hand on every release build made for device testing, so a
  // tester can confirm — via the Profile screen — which exact build is
  // actually installed, instead of assuming a fresh APK replaced an old
  // one. The Android versionCode in pubspec.yaml is bumped alongside this
  // for the same reason at the OS level.
  static const String buildLabel = 'build-2026-08-03-ios-legal-pages';

  static const String dbName = 'expense_tracker.db';
  static const int dbVersion = 7; // v3 adds budgets table, v4 adds soft-delete, v5 updates default category colors, v6 adds expenses.tax, v7 adds user_id to every table (cross-account data isolation)

  // SharedPreferences keys
  static const String prefOnboardingDone = 'onboarding_done';

  // Table names
  static const String expensesTable = 'expenses';
  static const String categoriesTable = 'categories';
  static const String budgetsTable = 'budgets';
}
