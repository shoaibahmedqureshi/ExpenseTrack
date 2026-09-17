import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async => _db ??= await _init();

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
        user_id     TEXT,
        FOREIGN KEY (category_id) REFERENCES ${AppConstants.categoriesTable}(id)
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
        user_id        TEXT,
        FOREIGN KEY (category_id) REFERENCES ${AppConstants.categoriesTable}(id)
      )
    ''');

    // No category seeding here — a brand new install has no authenticated
    // user yet at DB-creation time (this runs before sign-in), and default
    // categories are now a per-user concern (see ensureDefaultCategoriesForUser,
    // called once per successful sign-in) rather than a per-device one, to
    // match the per-user scoping every other table now has.
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add sync-tracking columns introduced in v2.
      await db.execute(
          'ALTER TABLE ${AppConstants.categoriesTable} ADD COLUMN remote_id TEXT');
      await db.execute(
          'ALTER TABLE ${AppConstants.categoriesTable} ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE ${AppConstants.expensesTable} ADD COLUMN remote_id TEXT');
      await db.execute(
          'ALTER TABLE ${AppConstants.expensesTable} ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      // Add budgets table introduced in v3.
      await db.execute('''
        CREATE TABLE ${AppConstants.budgetsTable} (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER,
          month       TEXT    NOT NULL,
          amount      REAL    NOT NULL,
          remote_id   TEXT,
          is_synced   INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (category_id) REFERENCES ${AppConstants.categoriesTable}(id)
        )
      ''');
    }
    if (oldVersion < 4) {
      // Soft-delete flag introduced in v4: a budget deletion now has to be
      // pushed to Supabase and reconciled on other devices before the row
      // actually disappears, so delete can no longer be an immediate local
      // DELETE (see BudgetLocalDatasource.delete and SyncService).
      await db.execute(
          'ALTER TABLE ${AppConstants.budgetsTable} ADD COLUMN pending_delete INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 5) {
      // Default category colors moved to the Fiscal Precision chart
      // palette in v5. Categories have no color-editing UI, so every row
      // with one of these names is still showing its original seed color
      // — safe to update by name with no risk of clobbering a user choice.
      await _updateDefaultCategoryColors(db);
    }
    if (oldVersion < 6) {
      // Tax-paid field introduced in v6 — informational breakdown of an
      // expense's amount (which already includes tax), not an addition to
      // it. Populated from the receipt scanner's separate tax extraction.
      await db.execute(
          'ALTER TABLE ${AppConstants.expensesTable} ADD COLUMN tax REAL');
    }
    if (oldVersion < 7) {
      // Per-user data isolation. Every local table previously had no owner
      // column at all — signing into a different Supabase account on the
      // same device showed that account every row any previous account had
      // ever created locally, a real cross-account data leak (and worse,
      // any not-yet-synced rows from the old account could get pushed to
      // Supabase tagged with the new account's uid the next time sync ran).
      //
      // Existing rows are backfilled to whoever is signed in at the moment
      // this migration runs. That's reliable for the common case — main()
      // awaits Supabase.initialize() (which restores a persisted session,
      // if any) before ever opening this database, so a device that was
      // already logged in when the app updated has its uid available right
      // here. If nobody happens to be signed in at this exact moment,
      // these legacy rows are simply left ownerless (invisible from then
      // on, to every account) rather than guessed at and handed to
      // whichever account happens to sign in next — that guess is exactly
      // the kind of cross-account leak this migration exists to close, so
      // an occasional lost pre-migration row is the far safer failure mode.
      await db.execute(
          'ALTER TABLE ${AppConstants.categoriesTable} ADD COLUMN user_id TEXT');
      await db.execute(
          'ALTER TABLE ${AppConstants.expensesTable} ADD COLUMN user_id TEXT');
      await db.execute(
          'ALTER TABLE ${AppConstants.budgetsTable} ADD COLUMN user_id TEXT');

      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        await db.update(AppConstants.categoriesTable, {'user_id': uid},
            where: 'user_id IS NULL');
        await db.update(AppConstants.expensesTable, {'user_id': uid},
            where: 'user_id IS NULL');
        await db.update(AppConstants.budgetsTable, {'user_id': uid},
            where: 'user_id IS NULL');
      }
    }
  }

  /// Seeds the default category set for [userId] if — and only if — they
  /// don't already have any local categories. Called once per successful
  /// sign-in (see AuthProvider), not from _onCreate: categories are scoped
  /// per-user now, so what to seed depends on who's actually signed in,
  /// which isn't known yet when the database itself is first created.
  Future<void> ensureDefaultCategoriesForUser(String userId) async {
    final db = await database;
    final existing = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM ${AppConstants.categoriesTable} WHERE user_id = ?',
      [userId],
    ));
    if (existing != null && existing > 0) return;

    final defaults = [
      {'name': 'Food',           'icon_key': 'restaurant',             'color': const Color(0xFFEF4444).value},
      {'name': 'Transport',      'icon_key': 'directions_car',         'color': const Color(0xFF3B82F6).value},
      {'name': 'Shopping',       'icon_key': 'shopping_bag',           'color': const Color(0xFF06B6D4).value},
      {'name': 'Health',         'icon_key': 'favorite',               'color': const Color(0xFF10B981).value},
      {'name': 'Entertainment',  'icon_key': 'movie',                  'color': const Color(0xFFFBBF24).value},
      {'name': 'Salary',         'icon_key': 'account_balance_wallet', 'color': const Color(0xFF8B5CF6).value},
      {'name': 'Other',          'icon_key': 'category',               'color': const Color(0xFF64748B).value},
    ];
    for (final c in defaults) {
      await db.insert(AppConstants.categoriesTable, {...c, 'user_id': userId});
    }
  }

  // Same name → color mapping as ensureDefaultCategoriesForUser's `defaults`
  // above, applied
  // as an UPDATE instead of an INSERT for databases that already exist.
  Future<void> _updateDefaultCategoryColors(Database db) async {
    final colors = {
      'Food': const Color(0xFFEF4444).value,
      'Transport': const Color(0xFF3B82F6).value,
      'Shopping': const Color(0xFF06B6D4).value,
      'Health': const Color(0xFF10B981).value,
      'Entertainment': const Color(0xFFFBBF24).value,
      'Salary': const Color(0xFF8B5CF6).value,
      'Other': const Color(0xFF64748B).value,
    };
    for (final entry in colors.entries) {
      await db.update(
        AppConstants.categoriesTable,
        {'color': entry.value},
        where: 'name = ?',
        whereArgs: [entry.key],
      );
    }
  }
}
