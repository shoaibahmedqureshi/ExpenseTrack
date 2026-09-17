import 'package:flutter/foundation.dart';
import '../../domain/entities/expense.dart';
import '../../domain/usecases/get_expenses_usecase.dart';
import '../../domain/usecases/manage_expense_usecase.dart';

class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider({
    required GetExpensesUsecase getExpenses,
    required ManageExpenseUsecase manageExpense,
  })  : _get = getExpenses,
        _manage = manageExpense;

  final GetExpensesUsecase _get;
  final ManageExpenseUsecase _manage;

  List<Expense> _expenses = [];
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _error;

  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;
  // Distinct from isLoading: Dashboard uses this to show a full-screen
  // loader only for the very first load (which now often overlaps with
  // sync — can take a few seconds on a fresh device) rather than flashing
  // a zero-balance/empty-transactions dashboard for a frame before that
  // first load kicks in, or on every subsequent pull-to-refresh.
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get error => _error;

  double get totalIncome => _expenses
      .where((e) => e.isIncome)
      .fold(0, (sum, e) => sum + e.amount);

  double get totalExpense => _expenses
      .where((e) => e.isExpense)
      .fold(0, (sum, e) => sum + e.amount);

  double get balance => totalIncome - totalExpense;

  // Filters the already-loaded in-memory list rather than re-querying the
  // DB — the Dashboard needs several different date-range slices (this
  // month, last month, this year) and everything is already loaded via
  // loadAll(), so there's no reason to round-trip to SQLite for each one.
  List<Expense> inRange(DateTime from, DateTime toExclusive) => _expenses
      .where((e) => !e.date.isBefore(from) && e.date.isBefore(toExclusive))
      .toList();

  double incomeIn(DateTime from, DateTime toExclusive) =>
      inRange(from, toExclusive)
          .where((e) => e.isIncome)
          .fold(0, (sum, e) => sum + e.amount);

  double expenseIn(DateTime from, DateTime toExclusive) =>
      inRange(from, toExclusive)
          .where((e) => e.isExpense)
          .fold(0, (sum, e) => sum + e.amount);

  Future<void> loadAll() => _run(() async {
        _expenses = await _get.all();
      });

  Future<void> loadByDateRange(DateTime from, DateTime to) =>
      _run(() async {
        _expenses = await _get.byDateRange(from, to);
      });

  Future<void> add(Expense expense) => _run(() async {
        final id = await _manage.add(expense);
        _expenses = [expense.copyWith(id: id), ..._expenses];
      });

  Future<void> edit(Expense expense) => _run(() async {
        await _manage.edit(expense);
        final idx = _expenses.indexWhere((e) => e.id == expense.id);
        if (idx != -1) _expenses[idx] = expense;
      });

  Future<void> remove(int id) => _run(() async {
        await _manage.remove(id);
        _expenses = _expenses.where((e) => e.id != id).toList();
      });

  /// Drops the in-memory list on sign-out — see CategoryProvider.clear()
  /// for why this matters even though every local query is uid-scoped now.
  void clear() {
    _expenses = [];
    _hasLoadedOnce = false;
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
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }
}
