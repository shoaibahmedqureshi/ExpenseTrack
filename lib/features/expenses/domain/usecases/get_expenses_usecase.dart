import '../entities/expense.dart';
import '../repositories/expense_repository.dart';

class GetExpensesUsecase {
  const GetExpensesUsecase(this._repository);

  final ExpenseRepository _repository;

  Future<List<Expense>> all() => _repository.getAll();

  Future<List<Expense>> byDateRange(DateTime from, DateTime to) =>
      _repository.getByDateRange(from, to);

  Future<List<Expense>> byCategory(int categoryId) =>
      _repository.getByCategory(categoryId);
}
