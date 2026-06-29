import '../entities/budget.dart';

abstract interface class BudgetRepository {
  Future<List<Budget>> getByMonth(DateTime month);
  Future<int> insert(Budget budget);
  Future<void> update(Budget budget);
  Future<void> delete(int id);
}
