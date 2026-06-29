import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';
import '../datasources/budget_local_datasource.dart';
import '../models/budget_model.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  BudgetRepositoryImpl(this._datasource);

  final BudgetLocalDatasource _datasource;

  @override
  Future<List<Budget>> getByMonth(DateTime month) =>
      _datasource.getByMonth(month);

  @override
  Future<int> insert(Budget budget) =>
      _datasource.insert(BudgetModel.fromEntity(budget));

  @override
  Future<void> update(Budget budget) =>
      _datasource.update(BudgetModel.fromEntity(budget));

  @override
  Future<void> delete(int id) => _datasource.delete(id);
}
