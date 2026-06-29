import '../entities/budget.dart';
import '../repositories/budget_repository.dart';

class ManageBudgetUsecase {
  const ManageBudgetUsecase(this._repository);

  final BudgetRepository _repository;

  Future<int> add(Budget budget) => _repository.insert(budget);
  Future<void> edit(Budget budget) => _repository.update(budget);
  Future<void> remove(int id) => _repository.delete(id);
}
