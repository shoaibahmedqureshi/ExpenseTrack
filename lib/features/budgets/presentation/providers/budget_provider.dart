import 'package:flutter/foundation.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/domain/usecases/get_expenses_usecase.dart';
import '../../domain/entities/budget.dart';
import '../../domain/usecases/get_budgets_usecase.dart';
import '../../domain/usecases/manage_budget_usecase.dart';

class BudgetProvider extends ChangeNotifier {
  BudgetProvider({
    required GetBudgetsUsecase getBudgets,
    required ManageBudgetUsecase manageBudget,
    required GetExpensesUsecase getExpenses,
  })  : _get = getBudgets,
        _manage = manageBudget,
        _getExpenses = getExpenses;

  final GetBudgetsUsecase _get;
  final ManageBudgetUsecase _manage;
  final GetExpensesUsecase _getExpenses;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<Budget> _budgets = [];
  Map<int?, double> _spentByCategory = {};
  bool _isLoading = false;
  String? _error;

  DateTime get month => _month;
  List<Budget> get budgets => _budgets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalBudgeted => _budgets.fold(0, (sum, b) => sum + b.amount);
  double get totalSpent => _spentByCategory.values.fold(0, (sum, v) => sum + v);

  double spentFor(Budget budget) => _spentByCategory[budget.categoryId] ?? 0;

  double progressFor(Budget budget) {
    if (budget.amount <= 0) return 0;
    return (spentFor(budget) / budget.amount).clamp(0, double.infinity);
  }

  bool isOverBudget(Budget budget) => spentFor(budget) > budget.amount;

  Future<void> load([DateTime? month]) => _run(() async {
        _month = month != null
            ? DateTime(month.year, month.month, 1)
            : _month;
        _budgets = await _get.byMonth(_month);

        final monthEnd = DateTime(_month.year, _month.month + 1, 1)
            .subtract(const Duration(seconds: 1));
        final expenses = await _getExpenses.byDateRange(_month, monthEnd);
        _spentByCategory = _aggregateByCategory(expenses);
      });

  Future<void> setMonth(DateTime month) => load(month);

  Future<void> previousMonth() =>
      load(DateTime(_month.year, _month.month - 1, 1));

  Future<void> nextMonth() => load(DateTime(_month.year, _month.month + 1, 1));

  Future<void> add(Budget budget) => _run(() async {
        final id = await _manage.add(budget);
        _budgets = [..._budgets, budget.copyWith(id: id)];
      });

  Future<void> edit(Budget budget) => _run(() async {
        await _manage.edit(budget);
        final idx = _budgets.indexWhere((b) => b.id == budget.id);
        if (idx != -1) _budgets[idx] = budget;
      });

  Future<void> remove(int id) => _run(() async {
        await _manage.remove(id);
        _budgets = _budgets.where((b) => b.id != id).toList();
      });

  Map<int?, double> _aggregateByCategory(List<Expense> expenses) {
    final map = <int?, double>{};
    for (final e in expenses.where((e) => e.isExpense)) {
      map[e.category.id] = (map[e.category.id] ?? 0) + e.amount;
    }
    return map;
  }

  Future<void> _run(Future<void> Function() fn) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await fn();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
