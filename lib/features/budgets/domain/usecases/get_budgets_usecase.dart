import '../entities/budget.dart';
import '../repositories/budget_repository.dart';

class GetBudgetsUsecase {
  const GetBudgetsUsecase(this._repository);

  final BudgetRepository _repository;

  Future<List<Budget>> byMonth(DateTime month) => _repository.getByMonth(month);
}
