import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../categories/data/models/category_model.dart';
import '../models/expense_model.dart';
import '../../domain/entities/expense.dart';

class ExpenseLocalDatasource {
  // uidOverride is a testing seam only (see SyncService's own uidOverride
  // for the same reasoning) — a test's Database has no real Supabase
  // session to read a uid from. Production call sites never pass it.
  ExpenseLocalDatasource(this._db, {String? uidOverride})
      : _uidOverride = uidOverride;

  final Database _db;
  final String? _uidOverride;

  // Read live at each call rather than captured once in a field: this
  // datasource is constructed a single time at app start (see main.dart)
  // and reused for the whole process lifetime, so it has to reflect
  // whoever is signed in *right now*, including across a sign-out and a
  // different account signing back in — not whoever was signed in when the
  // app launched.
  String? get _uid =>
      _uidOverride ?? Supabase.instance.client.auth.currentUser?.id;

  Future<List<ExpenseModel>> getAll() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _db.rawQuery('''
      SELECT e.*,
             c.id as c_id, c.name as c_name, c.icon_key, c.color
      FROM ${AppConstants.expensesTable} e
      JOIN ${AppConstants.categoriesTable} c ON e.category_id = c.id
      WHERE e.user_id = ?
      ORDER BY e.date DESC
    ''', [uid]);
    return rows.map(_mapRow).toList();
  }

  Future<List<ExpenseModel>> getByDateRange(
      DateTime from, DateTime to) async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _db.rawQuery('''
      SELECT e.*,
             c.id as c_id, c.name as c_name, c.icon_key, c.color
      FROM ${AppConstants.expensesTable} e
      JOIN ${AppConstants.categoriesTable} c ON e.category_id = c.id
      WHERE e.date BETWEEN ? AND ? AND e.user_id = ?
      ORDER BY e.date DESC
    ''', [from.toIso8601String(), to.toIso8601String(), uid]);
    return rows.map(_mapRow).toList();
  }

  Future<List<ExpenseModel>> getByCategory(int categoryId) async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _db.rawQuery('''
      SELECT e.*,
             c.id as c_id, c.name as c_name, c.icon_key, c.color
      FROM ${AppConstants.expensesTable} e
      JOIN ${AppConstants.categoriesTable} c ON e.category_id = c.id
      WHERE e.category_id = ? AND e.user_id = ?
      ORDER BY e.date DESC
    ''', [categoryId, uid]);
    return rows.map(_mapRow).toList();
  }

  Future<int> insert(ExpenseModel model) => _db.insert(
      AppConstants.expensesTable, {...model.toMap(), 'user_id': _uid});

  Future<void> update(ExpenseModel model) async {
    await _db.update(
      AppConstants.expensesTable,
      model.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [model.id, _uid],
    );
  }

  Future<void> delete(int id) async {
    await _db.delete(
      AppConstants.expensesTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _uid],
    );
  }

  Future<double> getTotalByType(TransactionType type) async {
    final result = await _db.rawQuery(
      'SELECT SUM(amount) as total FROM ${AppConstants.expensesTable} WHERE type = ? AND user_id = ?',
      [type.index, _uid],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  ExpenseModel _mapRow(Map<String, dynamic> row) {
    final category = CategoryModel.fromMap({
      'id': row['c_id'],
      'name': row['c_name'],
      'icon_key': row['icon_key'],
      'color': row['color'],
    });
    return ExpenseModel.fromMap(row, category);
  }
}
