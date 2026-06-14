import '../entities/expense.dart';

abstract interface class ExpenseRepository {
  Future<List<Expense>> getAll();
  Future<List<Expense>> getByDateRange(DateTime from, DateTime to);
  Future<List<Expense>> getByCategory(int categoryId);
  Future<Expense> getById(int id);
  Future<int> insert(Expense expense);
  Future<void> update(Expense expense);
  Future<void> delete(int id);
  Future<double> getTotalByType(TransactionType type);
}
