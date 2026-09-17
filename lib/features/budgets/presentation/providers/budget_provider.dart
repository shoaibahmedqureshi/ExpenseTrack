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

  // Set right after add()/edit() when saving a category budget caused the
  // Overall budget to auto-increase (see _syncOverallWithCategories) — the
  // UI reads this once to show a one-time "we bumped your overall budget"
  // dialog, then it's cleared on the next add()/edit() call.
  ({double from, double to})? _lastAutoIncrease;

  DateTime get month => _month;
  List<Budget> get budgets => _budgets;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ({double from, double to})? get lastAutoIncrease => _lastAutoIncrease;
  // Exposed for the temporary budget_debug_logs snapshot (see
  // budgets_screen.dart) — not otherwise needed outside this class.
  Map<int?, double> get spentByCategory => _spentByCategory;

  // Category budgets are a breakdown OF the overall budget, not additive
  // on top of it — an Overall of $1,600 with $400 in category budgets
  // means $1,600 total, not $2,000. If no Overall is set, fall back to
  // the sum of category budgets as the best available total.
  double get totalBudgeted {
    final overall = _budgets.where((b) => b.isOverall).toList();
    if (overall.isNotEmpty) return overall.first.amount;
    return _budgets
        .where((b) => !b.isOverall)
        .fold(0.0, (sum, b) => sum + b.amount);
  }

  double get totalSpent => _spentByCategory.values.fold(0, (sum, v) => sum + v);

  double spentFor(Budget budget) =>
      budget.isOverall ? totalSpent : (_spentByCategory[budget.categoryId] ?? 0);

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
        _lastAutoIncrease = null;
        final id = await _manage.add(budget);
        _budgets = [..._budgets, budget.copyWith(id: id)];
        if (!budget.isOverall) await _syncOverallWithCategories();
      });

  Future<void> edit(Budget budget) => _run(() async {
        _lastAutoIncrease = null;
        await _manage.edit(budget);
        // Rebuilds via .map().toList() rather than mutating _budgets[idx]
        // in place: _budgets is loaded from a datasource that returns
        // List<BudgetModel>, and Dart's generic lists are covariant but
        // checked on write — assigning a plain Budget (not BudgetModel)
        // into that list at a specific index throws
        // "type 'Budget' is not a subtype of type 'BudgetModel' of
        // 'value'" at runtime, even though it type-checks statically as
        // List<Budget>. add()/remove() already sidestep this by producing
        // a fresh list via spread/.toList(), which reifies as List<Budget>
        // from this method's own static type instead of inheriting the
        // original list's runtime type.
        _budgets = _budgets.map((b) => b.id == budget.id ? budget : b).toList();
        if (!budget.isOverall) await _syncOverallWithCategories();
      });

  // Category budgets are meant to sum up to the Overall budget, not sit
  // alongside it — if saving a category budget pushes the category total
  // past the current Overall, the Overall auto-increases to match rather
  // than silently understating what's actually budgeted. Only handles the
  // "categories exceed overall" direction — it never auto-decreases an
  // Overall the user set deliberately higher than their categories add up
  // to (e.g. leaving room for categories not yet budgeted).
  Future<void> _syncOverallWithCategories() async {
    final overallIndex = _budgets.indexWhere((b) => b.isOverall);
    if (overallIndex == -1) return;
    final overall = _budgets[overallIndex];
    final categorySum = _budgets
        .where((b) => !b.isOverall)
        .fold(0.0, (sum, b) => sum + b.amount);
    if (categorySum > overall.amount) {
      final updated = overall.copyWith(amount: categorySum);
      await _manage.edit(updated);
      _budgets =
          _budgets.map((b) => b.id == overall.id ? updated : b).toList();
      _lastAutoIncrease = (from: overall.amount, to: categorySum);
    }
  }

  Future<void> remove(int id) => _run(() async {
        await _manage.remove(id);
        _budgets = _budgets.where((b) => b.id != id).toList();
      });

  // Deliberately separate from load()/_month: the Dashboard's Year toggle
  // needs an aggregate across 12 months without disturbing the
  // single-month state the Budgets tab is built around, so this returns
  // its own result rather than mutating _budgets/_spentByCategory.
  Future<({double budgeted, double spent})> yearSummary(int year) async {
    var budgeted = 0.0;
    for (var m = 1; m <= 12; m++) {
      final monthBudgets = await _get.byMonth(DateTime(year, m, 1));
      // Same rule as totalBudgeted: a month's Overall already represents
      // its total (categories sum up to it), so only add categories when
      // there's no Overall row to avoid double-counting.
      final monthOverall = monthBudgets.where((b) => b.isOverall).toList();
      budgeted += monthOverall.isNotEmpty
          ? monthOverall.first.amount
          : monthBudgets
              .where((b) => !b.isOverall)
              .fold(0.0, (sum, b) => sum + b.amount);
    }
    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year + 1, 1, 1).subtract(const Duration(seconds: 1));
    final expenses = await _getExpenses.byDateRange(yearStart, yearEnd);
    final spent =
        expenses.where((e) => e.isExpense).fold(0.0, (sum, e) => sum + e.amount);
    return (budgeted: budgeted, spent: spent);
  }

  Map<int?, double> _aggregateByCategory(List<Expense> expenses) {
    final map = <int?, double>{};
    for (final e in expenses.where((e) => e.isExpense)) {
      map[e.category.id] = (map[e.category.id] ?? 0) + e.amount;
    }
    return map;
  }

  /// Drops the in-memory list on sign-out — see CategoryProvider.clear()
  /// for why this matters even though every local query is uid-scoped now.
  void clear() {
    _budgets = [];
    _spentByCategory = {};
    notifyListeners();
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
