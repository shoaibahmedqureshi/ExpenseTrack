import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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
        is_synced  INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.expensesTable} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        title       TEXT    NOT NULL,
        amount      REAL    NOT NULL,
        date        TEXT    NOT NULL,
        type        INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        note        TEXT,
        remote_id   TEXT,
        is_synced   INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES ${AppConstants.categoriesTable}(id)
      )
    ''');

    await _seedCategories(db);
    await _createPendingDeletesTable(db);
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
      // Tombstones for remote deletes introduced in v3.
      await _createPendingDeletesTable(db);
    }
  }

  Future<void> _createPendingDeletesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.pendingDeletesTable} (
        table_name TEXT NOT NULL,
        remote_id  TEXT NOT NULL
      )
    ''');
  }

  /// Wipes all locally cached data and reseeds defaults.
  ///
  /// Local tables aren't scoped by user id, so switching accounts on the
  /// same device must clear the previous account's rows before syncing —
  /// otherwise stale data from the old account lingers and gets mixed in.
  Future<void> resetForNewUser() async {
    final db = await database;
    await db.delete(AppConstants.expensesTable);
    await db.delete(AppConstants.categoriesTable);
    await db.delete(AppConstants.pendingDeletesTable);
    await _seedCategories(db);
  }

  Future<void> _seedCategories(Database db) async {
    final defaults = [
      {'name': 'Food',           'icon_key': 'restaurant',             'color': const Color(0xFFFF6B6B).value},
      {'name': 'Transport',      'icon_key': 'directions_car',         'color': const Color(0xFF4ECDC4).value},
      {'name': 'Shopping',       'icon_key': 'shopping_bag',           'color': const Color(0xFF45B7D1).value},
      {'name': 'Health',         'icon_key': 'favorite',               'color': const Color(0xFF96CEB4).value},
      {'name': 'Entertainment',  'icon_key': 'movie',                  'color': const Color(0xFFFFEAA7).value},
      {'name': 'Salary',         'icon_key': 'account_balance_wallet', 'color': const Color(0xFF6C63FF).value},
      {'name': 'Other',          'icon_key': 'category',               'color': const Color(0xFF9094A6).value},
    ];
    for (final c in defaults) {
      await db.insert(AppConstants.categoriesTable, c);
    }
  }
}
