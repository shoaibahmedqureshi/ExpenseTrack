import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:outlay/core/constants/app_constants.dart';
import 'package:outlay/features/sync/sync_service.dart';

/// Exercises SyncService.dedupeLocalCategories() against a real in-memory
/// SQLite database — this is the actual production execution path, not a
/// reimplementation of it, so a bug in the real reassign-then-delete logic
/// (e.g. wrong table, wrong column, wrong order) would show up here as a
/// failing assertion on real query results, not just a plausible-looking
/// mock expectation.
///
/// No network happens in any of these tests — SupabaseClient is only
/// constructed to satisfy SyncService's constructor; dedupeLocalCategories
/// never touches it.
void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE ${AppConstants.categoriesTable} (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        icon_key   TEXT    NOT NULL,
        color      INTEGER NOT NULL,
        remote_id  TEXT,
        is_synced  INTEGER NOT NULL DEFAULT 0,
        user_id    TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE ${AppConstants.expensesTable} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        title       TEXT    NOT NULL,
        amount      REAL    NOT NULL,
        tax         REAL,
        date        TEXT    NOT NULL,
        type        INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        note        TEXT,
        remote_id   TEXT,
        is_synced   INTEGER NOT NULL DEFAULT 0,
        user_id     TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE ${AppConstants.budgetsTable} (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id    INTEGER,
        month          TEXT    NOT NULL,
        amount         REAL    NOT NULL,
        remote_id      TEXT,
        is_synced      INTEGER NOT NULL DEFAULT 0,
        pending_delete INTEGER NOT NULL DEFAULT 0,
        user_id        TEXT
      )
    ''');
  });

  tearDown(() async {
    await db.close();
  });

  // Every row inserted directly in these tests is tagged with this same
  // uid, and SyncService is given it via uidOverride (there's no real
  // Supabase session in a unit test) — dedupeLocalCategories/
  // dedupeLocalBudgets are scoped per-user now, so without both sides
  // matching, every query here would simply find nothing.
  const testUid = 'test-user-1';

  SyncService makeSyncService() => SyncService(
        db,
        SupabaseClient('https://example.supabase.co', 'anon-key-not-used'),
        uidOverride: testUid,
      );

  test('no-op when there are no duplicate category names', () async {
    await db.insert(AppConstants.categoriesTable,
        {'name': 'Food', 'icon_key': 'restaurant', 'color': 1, 'user_id': testUid});
    await db.insert(AppConstants.categoriesTable,
        {'name': 'Transport', 'icon_key': 'directions_car', 'color': 2, 'user_id': testUid});

    await makeSyncService().dedupeLocalCategories();

    final remaining = await db.query(AppConstants.categoriesTable);
    expect(remaining, hasLength(2));
  });

  test(
      'CRITICAL: merges a duplicate category without losing or orphaning '
      'the expense that referenced it — this is the exact "previous data '
      'disappeared" scenario. An expense pointed at the duplicate id must '
      'end up pointing at the keeper id, still present, still with its '
      'original amount/title, after the duplicate row is deleted.',
      () async {
    final keeperId = await db.insert(AppConstants.categoriesTable,
        {'name': 'Food', 'icon_key': 'restaurant', 'color': 1, 'remote_id': '10', 'is_synced': 1, 'user_id': testUid});
    final dupId = await db.insert(AppConstants.categoriesTable,
        {'name': 'Food', 'icon_key': 'restaurant', 'color': 1, 'remote_id': '11', 'is_synced': 1, 'user_id': testUid});

    final expenseId = await db.insert(AppConstants.expensesTable, {
      'title': 'Groceries',
      'amount': 42.50,
      'date': '2026-07-01T00:00:00.000',
      'type': 0,
      'category_id': dupId, // pulled in referencing the duplicate
      'remote_id': '999',
      'is_synced': 1,
      'user_id': testUid,
    });

    await makeSyncService().dedupeLocalCategories();

    // The duplicate category is gone...
    final categories = await db.query(AppConstants.categoriesTable);
    expect(categories, hasLength(1));
    expect(categories.first['id'], keeperId);

    // ...but the expense is not. It survived, unchanged apart from now
    // pointing at the keeper.
    final expenses = await db.query(AppConstants.expensesTable);
    expect(expenses, hasLength(1));
    expect(expenses.first['id'], expenseId);
    expect(expenses.first['title'], 'Groceries');
    expect(expenses.first['amount'], 42.50);
    expect(expenses.first['category_id'], keeperId);

    // And it's actually reachable through the same INNER JOIN the app's
    // real expense list query uses — this is what "disappeared" meant in
    // practice: an expense whose category_id matches nothing is invisible
    // everywhere, not just wrong in some field.
    final joined = await db.rawQuery('''
      SELECT e.id FROM ${AppConstants.expensesTable} e
      JOIN ${AppConstants.categoriesTable} c ON e.category_id = c.id
    ''');
    expect(joined, hasLength(1));
  });

  test('merges a duplicate category without losing a budget that '
      'referenced it', () async {
    final keeperId = await db.insert(AppConstants.categoriesTable,
        {'name': 'Food', 'icon_key': 'restaurant', 'color': 1, 'remote_id': '10', 'user_id': testUid});
    final dupId = await db.insert(AppConstants.categoriesTable,
        {'name': 'Food', 'icon_key': 'restaurant', 'color': 1, 'remote_id': '11', 'user_id': testUid});

    await db.insert(AppConstants.budgetsTable, {
      'category_id': dupId,
      'month': '2026-07',
      'amount': 500.0,
      'user_id': testUid,
    });

    await makeSyncService().dedupeLocalCategories();

    final budgets = await db.query(AppConstants.budgetsTable);
    expect(budgets, hasLength(1));
    expect(budgets.first['category_id'], keeperId);
    expect(budgets.first['amount'], 500.0);
  });

  test('three-way duplicate merges expenses from all duplicates onto the '
      'single surviving keeper', () async {
    final keeperId = await db.insert(AppConstants.categoriesTable,
        {'name': 'Food', 'icon_key': 'restaurant', 'color': 1, 'remote_id': '10', 'user_id': testUid});
    final dup1 = await db.insert(AppConstants.categoriesTable,
        {'name': 'Food', 'icon_key': 'restaurant', 'color': 1, 'user_id': testUid});
    final dup2 = await db.insert(AppConstants.categoriesTable,
        {'name': 'Food', 'icon_key': 'restaurant', 'color': 1, 'user_id': testUid});

    await db.insert(AppConstants.expensesTable, {
      'title': 'A', 'amount': 1.0, 'date': '2026-07-01T00:00:00.000',
      'type': 0, 'category_id': dup1, 'user_id': testUid,
    });
    await db.insert(AppConstants.expensesTable, {
      'title': 'B', 'amount': 2.0, 'date': '2026-07-02T00:00:00.000',
      'type': 0, 'category_id': dup2, 'user_id': testUid,
    });
    await db.insert(AppConstants.expensesTable, {
      'title': 'C', 'amount': 3.0, 'date': '2026-07-03T00:00:00.000',
      'type': 0, 'category_id': keeperId, 'user_id': testUid,
    });

    await makeSyncService().dedupeLocalCategories();

    final categories = await db.query(AppConstants.categoriesTable);
    expect(categories, hasLength(1));

    final expenses = await db.query(AppConstants.expensesTable);
    expect(expenses, hasLength(3), reason: 'no expense should be deleted');
    expect(expenses.every((e) => e['category_id'] == keeperId), isTrue);
  });

  test('categories with genuinely different names are never merged',
      () async {
    await db.insert(AppConstants.categoriesTable,
        {'name': 'Food', 'icon_key': 'restaurant', 'color': 1, 'user_id': testUid});
    await db.insert(AppConstants.categoriesTable,
        {'name': 'Foodie Rewards', 'icon_key': 'card_giftcard', 'color': 2, 'user_id': testUid});

    await makeSyncService().dedupeLocalCategories();

    final categories = await db.query(AppConstants.categoriesTable);
    expect(categories, hasLength(2));
  });
}
