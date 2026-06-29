class AppConstants {
  AppConstants._();

  static const String appName = 'Outlay';
  static const String dbName = 'expense_tracker.db';
  static const int dbVersion = 3; // v3 adds budgets table

  // SharedPreferences keys
  static const String prefOnboardingDone = 'onboarding_done';

  // Table names
  static const String expensesTable = 'expenses';
  static const String categoriesTable = 'categories';
  static const String budgetsTable = 'budgets';
}
