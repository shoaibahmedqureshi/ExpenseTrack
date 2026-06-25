import 'package:flutter/foundation.dart';
import '../../../../core/utils/error_translator.dart';
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
  String? _error;

  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalIncome => _expenses
      .where((e) => e.isIncome)
      .fold(0, (sum, e) => sum + e.amount);

  double get totalExpense => _expenses
      .where((e) => e.isExpense)
      .fold(0, (sum, e) => sum + e.amount);

  double get balance => totalIncome - totalExpense;

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

  Future<void> _run(Future<void> Function() fn) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await fn();
    } catch (e) {
      _error = friendlyErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
