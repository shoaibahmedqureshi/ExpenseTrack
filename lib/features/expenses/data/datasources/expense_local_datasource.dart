import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../categories/data/models/category_model.dart';
import '../models/expense_model.dart';
import '../../domain/entities/expense.dart';

class ExpenseLocalDatasource {
  ExpenseLocalDatasource(this._db);

  final Database _db;

  Future<List<ExpenseModel>> getAll() async {
    final rows = await _db.rawQuery('''
      SELECT e.*,
             c.id as c_id, c.name as c_name, c.icon_key, c.color
      FROM ${AppConstants.expensesTable} e
      JOIN ${AppConstants.categoriesTable} c ON e.category_id = c.id
      ORDER BY e.date DESC
    ''');
    return rows.map(_mapRow).toList();
  }

  Future<List<ExpenseModel>> getByDateRange(
      DateTime from, DateTime to) async {
    final rows = await _db.rawQuery('''
      SELECT e.*,
             c.id as c_id, c.name as c_name, c.icon_key, c.color
      FROM ${AppConstants.expensesTable} e
      JOIN ${AppConstants.categoriesTable} c ON e.category_id = c.id
      WHERE e.date BETWEEN ? AND ?
      ORDER BY e.date DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return rows.map(_mapRow).toList();
  }

  Future<List<ExpenseModel>> getByCategory(int categoryId) async {
    final rows = await _db.rawQuery('''
      SELECT e.*,
             c.id as c_id, c.name as c_name, c.icon_key, c.color
      FROM ${AppConstants.expensesTable} e
      JOIN ${AppConstants.categoriesTable} c ON e.category_id = c.id
      WHERE e.category_id = ?
      ORDER BY e.date DESC
    ''', [categoryId]);
    return rows.map(_mapRow).toList();
  }

  Future<int> insert(ExpenseModel model) =>
      _db.insert(AppConstants.expensesTable, model.toMap());

  Future<void> update(ExpenseModel model) async {
    await _db.update(
      AppConstants.expensesTable,
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }

  Future<void> delete(int id) async {
    await _db.delete(
      AppConstants.expensesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getTotalByType(TransactionType type) async {
    final result = await _db.rawQuery(
      'SELECT SUM(amount) as total FROM ${AppConstants.expensesTable} WHERE type = ?',
      [type.index],
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
