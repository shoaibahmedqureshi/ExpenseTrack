class AppConstants {
  AppConstants._();

  static const String appName = 'Expense Tracker';
  static const String dbName = 'expense_tracker.db';
  static const int dbVersion = 3; // v3 adds pending_deletes tombstone table

  // SharedPreferences keys
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefLastUserId = 'last_synced_user_id';

  // Table names
  static const String expensesTable = 'expenses';
  static const String categoriesTable = 'categories';
  static const String pendingDeletesTable = 'pending_deletes';
}
