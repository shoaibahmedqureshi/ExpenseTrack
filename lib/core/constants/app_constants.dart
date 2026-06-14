class AppConstants {
  AppConstants._();

  static const String appName = 'Expense Tracker';
  static const String dbName = 'expense_tracker.db';
  static const int dbVersion = 2; // v2 adds remote_id + is_synced columns

  // SharedPreferences keys
  static const String prefOnboardingDone = 'onboarding_done';

  // Table names
  static const String expensesTable = 'expenses';
  static const String categoriesTable = 'categories';
}
