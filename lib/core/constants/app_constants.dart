class AppConstants {
  AppConstants._();

  static const String appName = 'Outlay';

  // Numeric Apple App ID (not the bundle ID) — from App Store Connect's
  // App Information page. Needed to build the direct offer-code redemption
  // URL (apps.apple.com/redeem?ctx=offercodes&id=...&code=...); left blank
  // until Shoaib provides it.
  static const String appleAppStoreId = '6790199113';

  // Shown on the Profile and Settings screens so a tester can confirm which build is installed. Bump it with
  // `version:` in pubspec.yaml on every release build.
  /// Must match `version:` in pubspec.yaml (a test checks that they do).
  static const String appVersion = '1.2.0';
  static const int appBuild = 52;
  static const String versionLabel = '$appVersion ($appBuild)';

  static const String dbName = 'expense_tracker.db';
  static const int dbVersion = 7; // v3 adds budgets table, v4 adds soft-delete, v5 updates default category colors, v6 adds expenses.tax, v7 adds user_id to every table (cross-account data isolation)

  // SharedPreferences keys
  static const String prefOnboardingDone = 'onboarding_done';

  // Table names
  static const String expensesTable = 'expenses';
  static const String categoriesTable = 'categories';
  static const String budgetsTable = 'budgets';
}
