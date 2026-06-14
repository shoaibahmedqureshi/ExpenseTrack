import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/domain/repositories/expense_repository.dart';
import '../datasources/expense_local_datasource.dart';
import '../models/expense_model.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl(this._datasource);

  final ExpenseLocalDatasource _datasource;

  @override
  Future<List<Expense>> getAll() => _datasource.getAll();

  @override
  Future<List<Expense>> getByDateRange(DateTime from, DateTime to) =>
      _datasource.getByDateRange(from, to);

  @override
  Future<List<Expense>> getByCategory(int categoryId) =>
      _datasource.getByCategory(categoryId);

  @override
  Future<Expense> getById(int id) async {
    final all = await _datasource.getAll();
    return all.firstWhere((e) => e.id == id);
  }

  @override
  Future<int> insert(Expense expense) =>
      _datasource.insert(ExpenseModel.fromEntity(expense));

  @override
  Future<void> update(Expense expense) =>
      _datasource.update(ExpenseModel.fromEntity(expense));

  @override
  Future<void> delete(int id) => _datasource.delete(id);

  @override
  Future<double> getTotalByType(TransactionType type) =>
      _datasource.getTotalByType(type);
}
