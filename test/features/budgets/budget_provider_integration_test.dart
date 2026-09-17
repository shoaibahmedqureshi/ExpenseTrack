import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:outlay/core/constants/app_constants.dart';
import 'package:outlay/features/budgets/data/datasources/budget_local_datasource.dart';
import 'package:outlay/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:outlay/features/budgets/domain/entities/budget.dart';
import 'package:outlay/features/budgets/domain/usecases/get_budgets_usecase.dart';
import 'package:outlay/features/budgets/domain/usecases/manage_budget_usecase.dart';
import 'package:outlay/features/budgets/presentation/providers/budget_provider.dart';
import 'package:outlay/features/categories/data/models/category_model.dart';
import 'package:outlay/features/expenses/data/datasources/expense_local_datasource.dart';
import 'package:outlay/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:outlay/features/expenses/domain/entities/expense.dart';
import 'package:outlay/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:outlay/features/expenses/domain/usecases/manage_expense_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:outlay/features/sync/sync_service.dart';

/// Drives the *real* BudgetProvider against a real in-memory database via
/// the real repositories/usecases/datasources — no mocking of the
/// aggregation logic itself, since that's exactly where "budget shows 0
/// spent despite expenses existing" would have to live if it's a real bug
/// rather than a stale-duplicate-category artifact.
void main() {
  late Database db;
  late int foodCategoryId;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Passed as uidOverride to every datasource/SyncService constructed below,
  // and stamped onto the handful of raw db.insert() calls that bypass the
  // repositories (categories, and a couple of hand-rolled budget rows) —
  // every local table/query is scoped per-user now (see DatabaseHelper /
  // ExpenseLocalDatasource / BudgetLocalDatasource / SyncService), so
  // without this every query in this file would simply find nothing.
  const testUid = 'test-user-1';

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE ${AppConstants.categoriesTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
        icon_key TEXT NOT NULL, color INTEGER NOT NULL,
        remote_id TEXT, is_synced INTEGER NOT NULL DEFAULT 0, user_id TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE ${AppConstants.expensesTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
        amount REAL NOT NULL, tax REAL, date TEXT NOT NULL, type INTEGER NOT NULL,
        category_id INTEGER NOT NULL, note TEXT,
        remote_id TEXT, is_synced INTEGER NOT NULL DEFAULT 0, user_id TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE ${AppConstants.budgetsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT, category_id INTEGER,
        month TEXT NOT NULL, amount REAL NOT NULL,
        remote_id TEXT, is_synced INTEGER NOT NULL DEFAULT 0,
        pending_delete INTEGER NOT NULL DEFAULT 0, user_id TEXT
      )
    ''');

    foodCategoryId = await db.insert(AppConstants.categoriesTable, {
      'name': 'Food',
      'icon_key': 'restaurant',
      'color': 0xFFFF6B6B,
      'user_id': testUid,
    });
  });

  tearDown(() async => db.close());

  BudgetProvider makeProvider() {
    final expenseRepo = ExpenseRepositoryImpl(
        ExpenseLocalDatasource(db, uidOverride: testUid));
    final budgetRepo = BudgetRepositoryImpl(
        BudgetLocalDatasource(db, uidOverride: testUid));
    return BudgetProvider(
      getBudgets: GetBudgetsUsecase(budgetRepo),
      manageBudget: ManageBudgetUsecase(budgetRepo),
      getExpenses: GetExpensesUsecase(expenseRepo),
    );
  }

  CategoryModel foodCategory() => CategoryModel(
        id: foodCategoryId,
        name: 'Food',
        icon: Icons.restaurant,
        color: const Color(0xFFFF6B6B),
      );

  test(
      'CRITICAL: a July expense against Food shows up as spend on a July '
      'Food budget — the exact scenario reported as broken', () async {
    final expenseRepo = ExpenseRepositoryImpl(ExpenseLocalDatasource(db, uidOverride: testUid));
    await expenseRepo.insert(Expense(
      title: 'Groceries',
      amount: 150.0,
      date: DateTime(2026, 7, 15),
      type: TransactionType.expense,
      category: foodCategory(),
    ));

    final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
    final budgetId = await budgetRepo.insert(Budget(
      categoryId: foodCategoryId,
      month: DateTime(2026, 7, 1),
      amount: 500.0,
    ));

    final provider = makeProvider();
    await provider.load(DateTime(2026, 7, 1));

    expect(provider.budgets, hasLength(1));
    final budget = provider.budgets.first;
    expect(budget.id, budgetId);
    expect(provider.spentFor(budget), 150.0,
        reason: 'this is the exact number that was reportedly showing 0');
  });

  test('expense dated on the 1st of the month (midnight, no time) is '
      'still included — a date-range boundary bug would show up here',
      () async {
    final expenseRepo = ExpenseRepositoryImpl(ExpenseLocalDatasource(db, uidOverride: testUid));
    await expenseRepo.insert(Expense(
      title: 'Month-start expense',
      amount: 20.0,
      date: DateTime(2026, 7, 1), // exactly midnight on the range's lower bound
      type: TransactionType.expense,
      category: foodCategory(),
    ));

    final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
    await budgetRepo.insert(Budget(
      categoryId: foodCategoryId,
      month: DateTime(2026, 7, 1),
      amount: 500.0,
    ));

    final provider = makeProvider();
    await provider.load(DateTime(2026, 7, 1));

    expect(provider.spentFor(provider.budgets.first), 20.0);
  });

  test('expense dated on the last day of the month (near-midnight) is '
      'still included', () async {
    final expenseRepo = ExpenseRepositoryImpl(ExpenseLocalDatasource(db, uidOverride: testUid));
    await expenseRepo.insert(Expense(
      title: 'Month-end expense',
      amount: 30.0,
      date: DateTime(2026, 7, 31, 23, 59),
      type: TransactionType.expense,
      category: foodCategory(),
    ));

    final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
    await budgetRepo.insert(Budget(
      categoryId: foodCategoryId,
      month: DateTime(2026, 7, 1),
      amount: 500.0,
    ));

    final provider = makeProvider();
    await provider.load(DateTime(2026, 7, 1));

    expect(provider.spentFor(provider.budgets.first), 30.0);
  });

  test('multiple July expenses against the same category sum correctly',
      () async {
    final expenseRepo = ExpenseRepositoryImpl(ExpenseLocalDatasource(db, uidOverride: testUid));
    for (final amt in [10.0, 20.0, 30.0]) {
      await expenseRepo.insert(Expense(
        title: 'Item',
        amount: amt,
        date: DateTime(2026, 7, 10),
        type: TransactionType.expense,
        category: foodCategory(),
      ));
    }

    final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
    await budgetRepo.insert(Budget(
      categoryId: foodCategoryId,
      month: DateTime(2026, 7, 1),
      amount: 500.0,
    ));

    final provider = makeProvider();
    await provider.load(DateTime(2026, 7, 1));

    expect(provider.spentFor(provider.budgets.first), 60.0);
  });

  test('income entries are excluded from spend even against the same '
      'category', () async {
    final expenseRepo = ExpenseRepositoryImpl(ExpenseLocalDatasource(db, uidOverride: testUid));
    await expenseRepo.insert(Expense(
      title: 'Refund',
      amount: 999.0,
      date: DateTime(2026, 7, 10),
      type: TransactionType.income,
      category: foodCategory(),
    ));
    await expenseRepo.insert(Expense(
      title: 'Real expense',
      amount: 40.0,
      date: DateTime(2026, 7, 10),
      type: TransactionType.expense,
      category: foodCategory(),
    ));

    final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
    await budgetRepo.insert(Budget(
      categoryId: foodCategoryId,
      month: DateTime(2026, 7, 1),
      amount: 500.0,
    ));

    final provider = makeProvider();
    await provider.load(DateTime(2026, 7, 1));

    expect(provider.spentFor(provider.budgets.first), 40.0);
  });

  test('an overall (no-category) budget aggregates spend across every '
      'category', () async {
    final transportId = await db.insert(AppConstants.categoriesTable, {
      'name': 'Transport',
      'icon_key': 'directions_car',
      'color': 0xFF4ECDC4,
      'user_id': testUid,
    });
    final transportCategory = CategoryModel(
      id: transportId,
      name: 'Transport',
      icon: Icons.directions_car,
      color: const Color(0xFF4ECDC4),
    );

    final expenseRepo = ExpenseRepositoryImpl(ExpenseLocalDatasource(db, uidOverride: testUid));
    await expenseRepo.insert(Expense(
      title: 'Groceries',
      amount: 40.0,
      date: DateTime(2026, 7, 10),
      type: TransactionType.expense,
      category: foodCategory(),
    ));
    await expenseRepo.insert(Expense(
      title: 'Uber',
      amount: 15.0,
      date: DateTime(2026, 7, 12),
      type: TransactionType.expense,
      category: transportCategory,
    ));

    final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
    await budgetRepo.insert(Budget(
      categoryId: null, // overall
      month: DateTime(2026, 7, 1),
      amount: 1000.0,
    ));

    final provider = makeProvider();
    await provider.load(DateTime(2026, 7, 1));

    expect(provider.budgets.first.isOverall, isTrue);
    expect(provider.spentFor(provider.budgets.first), 55.0);
  });

  test('a June expense does not count against a July budget for the same '
      'category', () async {
    final expenseRepo = ExpenseRepositoryImpl(ExpenseLocalDatasource(db, uidOverride: testUid));
    await expenseRepo.insert(Expense(
      title: 'June groceries',
      amount: 200.0,
      date: DateTime(2026, 6, 20),
      type: TransactionType.expense,
      category: foodCategory(),
    ));

    final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
    await budgetRepo.insert(Budget(
      categoryId: foodCategoryId,
      month: DateTime(2026, 7, 1),
      amount: 500.0,
    ));

    final provider = makeProvider();
    await provider.load(DateTime(2026, 7, 1));

    expect(provider.spentFor(provider.budgets.first), 0.0);
  });

  group('reported bug: duplicate categories causing 0 spend', () {
    test(
        'REPRODUCES THE BUG: a budget against one "Food" duplicate and an '
        'expense against a *different* "Food" duplicate (same name, '
        'different local id — exactly what existed before sync-side '
        'reconciliation) shows 0 spent, even though the expense is real '
        'and dated in the budget\'s month.', () async {
      // A second, genuinely duplicate "Food" row — simulates what existed
      // locally before push/pull reconciliation, or before dedup has run.
      final secondFoodId = await db.insert(AppConstants.categoriesTable, {
        'name': 'Food',
        'icon_key': 'restaurant',
        'color': 0xFFFF6B6B,
        'user_id': testUid,
      });
      final secondFoodCategory = CategoryModel(
        id: secondFoodId,
        name: 'Food',
        icon: Icons.restaurant,
        color: const Color(0xFFFF6B6B),
      );

      // Budget against the *first* Food (foodCategoryId).
      final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
      await budgetRepo.insert(Budget(
        categoryId: foodCategoryId,
        month: DateTime(2026, 7, 1),
        amount: 500.0,
      ));

      // Expense against the *second* Food (secondFoodId) — e.g. the user
      // picked "Food" from a picker that happened to hand back the other
      // duplicate row.
      final expenseRepo = ExpenseRepositoryImpl(ExpenseLocalDatasource(db, uidOverride: testUid));
      await expenseRepo.insert(Expense(
        title: 'Groceries',
        amount: 150.0,
        date: DateTime(2026, 7, 15),
        type: TransactionType.expense,
        category: secondFoodCategory,
      ));

      final beforeDedup = makeProvider();
      await beforeDedup.load(DateTime(2026, 7, 1));
      expect(beforeDedup.spentFor(beforeDedup.budgets.first), 0.0,
          reason: 'confirms the bug is reproduced: real expense, wrong id, '
              'shows as 0 spent');

      // Now run the actual remediation this app ships: SyncService's
      // dedupeLocalCategories, exactly as main.dart calls it on every app
      // start.
      final sync = SyncService(
        db,
        SupabaseClient('https://example.supabase.co', 'unused'),
        uidOverride: testUid,
      );
      await sync.dedupeLocalCategories();

      // Fresh provider + fresh load, simulating _reloadAfterSync().
      final afterDedup = makeProvider();
      await afterDedup.load(DateTime(2026, 7, 1));

      expect(afterDedup.budgets, hasLength(1));
      expect(afterDedup.spentFor(afterDedup.budgets.first), 150.0,
          reason: 'after dedup, the budget and the expense must resolve to '
              'the same surviving category id');
    });
  });

  group('reported bug: budget invisible after cross-device sync', () {
    test(
        'CRITICAL: a budget whose month is stored as a bare "2026-07-01" '
        '(what a Postgres `date` column returns via the REST API, and '
        'what _pullRemoteBudgets used to insert verbatim) is still found '
        'by getByMonth, even though a locally-created budget stores month '
        'as the full "2026-07-01T00:00:00.000". Confirmed with real device '
        'data: sync_debug_logs showed budgets_local_total: 7 (the row '
        'genuinely exists) while the very next budget_debug_logs snapshot '
        'from the same device showed budgets: [] — the row was there, the '
        'query just never matched its differently-formatted month string.',
        () async {
      // Bypasses BudgetModel.toMap()'s normalization on purpose, to
      // reproduce exactly what the old (buggy) _pullRemoteBudgets wrote.
      await db.insert(AppConstants.budgetsTable, {
        'category_id': foodCategoryId,
        'month': '2026-07-01', // bare date, no time component
        'amount': 500.0,
        'remote_id': '999',
        'is_synced': 1,
        'user_id': testUid,
      });

      final provider = makeProvider();
      await provider.load(DateTime(2026, 7, 1));

      expect(provider.budgets, hasLength(1),
          reason: 'the budget must be found regardless of which of the '
              'two month string formats it happens to be stored as');
      expect(provider.budgets.first.amount, 500.0);
    });

    test('a bare-date-format budget from one month does not leak into a '
        'different month\'s query', () async {
      await db.insert(AppConstants.budgetsTable, {
        'category_id': foodCategoryId,
        'month': '2026-06-01', // June, bare date format
        'amount': 300.0,
        'remote_id': '998',
        'is_synced': 1,
        'user_id': testUid,
      });

      final provider = makeProvider();
      await provider.load(DateTime(2026, 7, 1)); // asking for July

      expect(provider.budgets, isEmpty,
          reason: 'the date() normalization must still respect month '
              'boundaries, not just strip the time component blindly');
    });
  });

  group('reported bug: budget deletion should sync, not just disappear '
      'locally', () {
    test(
        'CRITICAL: removing a budget soft-deletes it — the row survives in '
        'the table (tombstoned) instead of being hard-deleted, so '
        'SyncService can still push the deletion to Supabase on the next '
        'sync', () async {
      final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
      final id = await budgetRepo.insert(Budget(
        categoryId: foodCategoryId,
        month: DateTime(2026, 7, 1),
        amount: 500.0,
      ));
      // Simulate it having already synced once, as a real deleted budget
      // usually would have.
      await db.update(AppConstants.budgetsTable,
          {'remote_id': '123', 'is_synced': 1},
          where: 'id = ?', whereArgs: [id]);

      final provider = makeProvider();
      await provider.load(DateTime(2026, 7, 1));
      await provider.remove(id);

      expect(provider.budgets, isEmpty,
          reason: 'the UI must not show a deleted budget any more');

      final rows = await db.query(AppConstants.budgetsTable,
          where: 'id = ?', whereArgs: [id]);
      expect(rows, hasLength(1),
          reason: 'the row must still exist locally as a tombstone — a '
              'hard delete here would give SyncService nothing to push, '
              'which is exactly why deletion never used to sync');
      expect(rows.first['pending_delete'], 1);
      expect(rows.first['is_synced'], 0,
          reason: 'must be marked unsynced again so SyncService picks it '
              'up as needing a push');
    });

    test('a soft-deleted (pending_delete) budget is excluded from '
        'getByMonth even though the row still physically exists', () async {
      final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
      final id = await budgetRepo.insert(Budget(
        categoryId: foodCategoryId,
        month: DateTime(2026, 7, 1),
        amount: 500.0,
      ));
      await budgetRepo.delete(id);

      final provider = makeProvider();
      await provider.load(DateTime(2026, 7, 1));

      expect(provider.budgets, isEmpty);
    });
  });

  group('reported bug: too many budget entries — one budget per category '
      'per month', () {
    test('SyncService.dedupeLocalBudgets tombstones extra budgets for the '
        'same category and month, keeping exactly one', () async {
      final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
      final keeperId = await budgetRepo.insert(Budget(
        categoryId: foodCategoryId,
        month: DateTime(2026, 7, 1),
        amount: 500.0,
      ));
      // Mark it synced, as the row other devices already know about.
      await db.update(AppConstants.budgetsTable,
          {'remote_id': '1', 'is_synced': 1},
          where: 'id = ?', whereArgs: [keeperId]);
      final duplicateId = await budgetRepo.insert(Budget(
        categoryId: foodCategoryId,
        month: DateTime(2026, 7, 1),
        amount: 700.0,
      ));

      final sync = SyncService(
        db,
        SupabaseClient('https://example.supabase.co', 'unused'),
        uidOverride: testUid,
      );
      await sync.dedupeLocalBudgets();

      final provider = makeProvider();
      await provider.load(DateTime(2026, 7, 1));

      expect(provider.budgets, hasLength(1),
          reason: 'only one Food budget for July should remain visible');
      expect(provider.budgets.first.id, keeperId,
          reason: 'the already-synced row should be kept, not the newer '
              'local-only duplicate');

      final dupRow = await db.query(AppConstants.budgetsTable,
          where: 'id = ?', whereArgs: [duplicateId]);
      expect(dupRow.first['pending_delete'], 1,
          reason: 'the duplicate must be tombstoned, not hard-deleted, so '
              'its removal is pushed to Supabase too');
    });

    test('dedupeLocalBudgets also merges duplicate Overall budgets '
        '(category_id null)', () async {
      final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
      await budgetRepo.insert(
          Budget(categoryId: null, month: DateTime(2026, 7, 1), amount: 1000.0));
      await budgetRepo.insert(
          Budget(categoryId: null, month: DateTime(2026, 7, 1), amount: 1200.0));

      final sync = SyncService(
        db,
        SupabaseClient('https://example.supabase.co', 'unused'),
        uidOverride: testUid,
      );
      await sync.dedupeLocalBudgets();

      final provider = makeProvider();
      await provider.load(DateTime(2026, 7, 1));

      expect(provider.budgets.where((b) => b.isOverall), hasLength(1),
          reason: 'exactly one Overall budget should survive for the month');
    });

    test('dedupeLocalBudgets does not touch budgets in different months or '
        'for different categories', () async {
      final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
      await budgetRepo.insert(Budget(
          categoryId: foodCategoryId, month: DateTime(2026, 7, 1), amount: 500.0));
      await budgetRepo.insert(Budget(
          categoryId: foodCategoryId, month: DateTime(2026, 8, 1), amount: 500.0));
      final otherCatId = await db.insert(AppConstants.categoriesTable, {
        'name': 'Transport',
        'icon_key': 'directions_car',
        'color': 0xFF4ECDC4,
        'user_id': testUid,
      });
      await budgetRepo.insert(
          Budget(categoryId: otherCatId, month: DateTime(2026, 7, 1), amount: 200.0));

      final sync = SyncService(
        db,
        SupabaseClient('https://example.supabase.co', 'unused'),
        uidOverride: testUid,
      );
      await sync.dedupeLocalBudgets();

      final all = await db.query(AppConstants.budgetsTable,
          where: 'pending_delete = 0');
      expect(all, hasLength(3),
          reason: 'none of these are real duplicates, so nothing should be '
              'tombstoned');
    });

    test(
        'REPRODUCES THE BUG: merging duplicate "Food" categories repoints '
        'two separately-created budgets onto the same surviving category, '
        'which dedupeLocalBudgets must then also clean up — this is the '
        'exact chain that produced "too many overall budget entries" on '
        'real devices', () async {
      final secondFoodId = await db.insert(AppConstants.categoriesTable, {
        'name': 'Food',
        'icon_key': 'restaurant',
        'color': 0xFFFF6B6B,
        'user_id': testUid,
      });

      final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
      await budgetRepo.insert(Budget(
          categoryId: foodCategoryId, month: DateTime(2026, 7, 1), amount: 500.0));
      await budgetRepo.insert(Budget(
          categoryId: secondFoodId, month: DateTime(2026, 7, 1), amount: 500.0));

      final sync = SyncService(
        db,
        SupabaseClient('https://example.supabase.co', 'unused'),
        uidOverride: testUid,
      );
      // Exactly the order main.dart and SyncService.run() use.
      await sync.dedupeLocalCategories();
      await sync.dedupeLocalBudgets();

      final provider = makeProvider();
      await provider.load(DateTime(2026, 7, 1));

      expect(provider.budgets, hasLength(1),
          reason: 'after both dedup passes, only one Food budget for July '
              'should remain, no matter how many duplicate categories fed '
              'into it');
    });
  });

  group('reported bug: editing a budget throws "Budget is not a subtype '
      'of type BudgetModel"', () {
    test(
        'CRITICAL: BudgetProvider.edit() must not throw when the loaded '
        'list came from the datasource (runtime type List<BudgetModel>) — '
        'writing a plain Budget into it via _budgets[idx] = budget hits '
        'Dart\'s covariant generic-list write check and throws at runtime '
        'even though it type-checks statically', () async {
      final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
      final id = await budgetRepo.insert(Budget(
        categoryId: foodCategoryId,
        month: DateTime(2026, 7, 1),
        amount: 500.0,
      ));

      final provider = makeProvider();
      // load() is what actually assigns _budgets from
      // GetBudgetsUsecase.byMonth(), which is the List<BudgetModel> whose
      // runtime type triggers the bug — constructing a BudgetProvider and
      // calling edit() without first load()ing wouldn't reproduce it.
      await provider.load(DateTime(2026, 7, 1));

      await provider.edit(Budget(id: id, categoryId: foodCategoryId,
          month: DateTime(2026, 7, 1), amount: 750.0));

      expect(provider.error, isNull,
          reason: 'edit must succeed without provider._run catching a '
              'covariant-list TypeError');
      expect(provider.budgets.single.amount, 750.0);
    });

    test('editing a budget that was already synced marks it unsynced '
        'again so the new amount actually reaches Supabase', () async {
      final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db, uidOverride: testUid));
      final id = await budgetRepo.insert(Budget(
        categoryId: foodCategoryId,
        month: DateTime(2026, 7, 1),
        amount: 500.0,
      ));
      await db.update(AppConstants.budgetsTable,
          {'remote_id': '42', 'is_synced': 1},
          where: 'id = ?', whereArgs: [id]);

      final provider = makeProvider();
      await provider.load(DateTime(2026, 7, 1));
      await provider.edit(Budget(id: id, categoryId: foodCategoryId,
          month: DateTime(2026, 7, 1), amount: 900.0));

      final row = await db.query(AppConstants.budgetsTable,
          where: 'id = ?', whereArgs: [id]);
      expect(row.first['is_synced'], 0,
          reason: 'BudgetModel.toMap() does not include is_synced, and '
              'SQLite UPDATE (unlike INSERT) leaves omitted columns '
              'untouched — without explicitly resetting it, an edited '
              'amount would silently never get pushed');
      expect(row.first['amount'], 900.0);
      // remote_id must survive the edit — it's how the eventual push
      // upsert knows to update the existing remote row instead of
      // creating a duplicate.
      expect(row.first['remote_id'], '42');
    });
  });
}
