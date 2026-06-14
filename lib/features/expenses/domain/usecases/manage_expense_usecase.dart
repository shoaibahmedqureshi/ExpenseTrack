import '../entities/expense.dart';
import '../repositories/expense_repository.dart';

class ManageExpenseUsecase {
  const ManageExpenseUsecase(this._repository);

  final ExpenseRepository _repository;

  Future<int> add(Expense expense) => _repository.insert(expense);
  Future<void> edit(Expense expense) => _repository.update(expense);
  Future<void> remove(int id) => _repository.delete(id);
}
