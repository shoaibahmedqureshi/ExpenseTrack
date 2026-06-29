import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/budget_model.dart';

class BudgetLocalDatasource {
  BudgetLocalDatasource(this._db);

  final Database _db;

  Future<List<BudgetModel>> getByMonth(DateTime month) async {
    final monthStart = DateTime(month.year, month.month, 1);
    final rows = await _db.query(
      AppConstants.budgetsTable,
      where: 'month = ?',
      whereArgs: [monthStart.toIso8601String()],
    );
    return rows.map(BudgetModel.fromMap).toList();
  }

  Future<int> insert(BudgetModel model) =>
      _db.insert(AppConstants.budgetsTable, model.toMap());

  Future<void> update(BudgetModel model) async {
    await _db.update(
      AppConstants.budgetsTable,
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }

  Future<void> delete(int id) async {
    await _db.delete(
      AppConstants.budgetsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
