import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:outlay/features/budgets/domain/entities/budget.dart';
import 'package:outlay/features/budgets/domain/repositories/budget_repository.dart';
import 'package:outlay/features/budgets/domain/usecases/get_budgets_usecase.dart';
import 'package:outlay/features/budgets/domain/usecases/manage_budget_usecase.dart';
import 'package:outlay/features/budgets/presentation/providers/budget_provider.dart';
import 'package:outlay/features/budgets/presentation/screens/budgets_screen.dart';
import 'package:outlay/features/categories/domain/entities/category.dart';
import 'package:outlay/features/categories/domain/repositories/category_repository.dart';
import 'package:outlay/features/categories/presentation/providers/category_provider.dart';
import 'package:outlay/features/expenses/domain/entities/expense.dart';
import 'package:outlay/features/expenses/domain/repositories/expense_repository.dart';
import 'package:outlay/features/expenses/domain/usecases/get_expenses_usecase.dart';

/// Deliberately NOT backed by sqflite_common_ffi: combining a real
/// FFI-backed database with widget-tree pumping hangs the test isolate in
/// this environment (see the identical warning already documented on
/// _GatedExpenseRepository in dashboard_loading_test.dart, and confirmed
/// again here — an earlier version of this file that used the real
/// datasource stack hung indefinitely on the very first testWidgets).
/// Plain in-memory fakes sidestep that entirely and are all this test
/// actually needs: it's asserting on layout and dialog behavior, not on
/// the real SQL/reconciliation logic (covered separately, without any
/// widget pumping, in budget_provider_integration_test.dart).
class _FakeBudgetRepository implements BudgetRepository {
  final List<Budget> store;
  _FakeBudgetRepository(this.store);

  @override
  Future<List<Budget>> getByMonth(DateTime month) async => store
      .where((b) => b.month.year == month.year && b.month.month == month.month)
      .toList();

  @override
  Future<int> insert(Budget budget) async {
    final id = (store.map((b) => b.id ?? 0).fold(0, (a, b) => a > b ? a : b)) + 1;
    store.add(budget.copyWith(id: id));
    return id;
  }

  @override
  Future<void> update(Budget budget) async {
    final idx = store.indexWhere((b) => b.id == budget.id);
    if (idx != -1) store[idx] = budget;
  }

  @override
  Future<void> delete(int id) async => store.removeWhere((b) => b.id == id);
}

class _FakeCategoryRepository implements CategoryRepository {
  final List<Category> categories;
  _FakeCategoryRepository(this.categories);

  @override
  Future<List<Category>> getAll() async => categories;
  @override
  Future<Category> getById(int id) async =>
      categories.firstWhere((c) => c.id == id);
  @override
  Future<int> insert(Category category) async => 1;
  @override
  Future<void> update(Category category) async {}
  @override
  Future<void> delete(int id) async {}
}

class _FakeExpenseRepository implements ExpenseRepository {
  @override
  Future<List<Expense>> getAll() async => [];
  @override
  Future<List<Expense>> getByDateRange(DateTime from, DateTime to) async => [];
  @override
  Future<List<Expense>> getByCategory(int categoryId) async => [];
  @override
  Future<Expense> getById(int id) async => throw UnimplementedError();
  @override
  Future<int> insert(Expense expense) async => 1;
  @override
  Future<void> update(Expense expense) async {}
  @override
  Future<void> delete(int id) async {}
  @override
  Future<double> getTotalByType(TransactionType type) async => 0;
}

void main() {
  // BudgetProvider.load() with no argument always defaults to the real
  // current month — a hardcoded month here would silently stop matching
  // once real time moves past it, leaving these tests exercising the
  // empty-state branch instead of the populated-tile layout they're
  // actually meant to cover.
  final currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  testWidgets(
      'CRITICAL: a budget tile with a long category name and a large '
      'amount does not overflow at a standard ~360dp phone width — this '
      'is the exact row that gained a second action icon (edit) alongside '
      'the pre-existing delete icon, reported as "layout tarnished"',
      (tester) async {
    final category = Category(
      id: 1,
      name: 'Entertainment & Subscriptions',
      icon: Icons.movie,
      color: const Color(0xFFFFEAA7),
    );
    final store = [
      Budget(id: 1, categoryId: 1, month: currentMonth, amount: 123456.78),
      Budget(id: 2, categoryId: null, month: currentMonth, amount: 500000.0),
    ];

    final categoryProvider =
        CategoryProvider(_FakeCategoryRepository([category]));
    final budgetRepo = _FakeBudgetRepository(store);
    final budgetProvider = BudgetProvider(
      getBudgets: GetBudgetsUsecase(budgetRepo),
      manageBudget: ManageBudgetUsecase(budgetRepo),
      getExpenses: GetExpensesUsecase(_FakeExpenseRepository()),
    );
    addTearDown(categoryProvider.dispose);
    addTearDown(budgetProvider.dispose);

    // A common Android phone width/height, not a tablet or a wide test
    // default — this is the class of device the report came from.
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: categoryProvider),
          ChangeNotifierProvider.value(value: budgetProvider),
        ],
        child: const MaterialApp(home: BudgetsScreen()),
      ),
    );
    // Flush initState's postFrameCallback (budgetProvider.load() then
    // categoryProvider.loadAll()) and the resulting rebuild.
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'no RenderFlex overflow or other layout exception should '
            'be thrown while laying out a budget tile');
    expect(find.text('Entertainment & Subscriptions'), findsOneWidget);
    // Exactly one compact menu per tile (edit+delete collapsed into it)
    // rather than two separate always-visible icon buttons.
    expect(find.byIcon(Icons.more_vert), findsWidgets);
    expect(find.byIcon(Icons.edit_outlined), findsNothing,
        reason: 'edit icon should be inside the popup menu, not rendered '
            'directly in the row');
  });

  testWidgets(
      'tapping the tile menu and choosing Edit opens the edit dialog '
      'pre-filled with the existing amount, and Save closes it without '
      'error', (tester) async {
    final category =
        Category(id: 1, name: 'Food', icon: Icons.restaurant, color: Colors.red);
    final store = [
      Budget(id: 1, categoryId: 1, month: currentMonth, amount: 500.0),
    ];

    final categoryProvider =
        CategoryProvider(_FakeCategoryRepository([category]));
    final budgetRepo = _FakeBudgetRepository(store);
    final budgetProvider = BudgetProvider(
      getBudgets: GetBudgetsUsecase(budgetRepo),
      manageBudget: ManageBudgetUsecase(budgetRepo),
      getExpenses: GetExpensesUsecase(_FakeExpenseRepository()),
    );
    addTearDown(categoryProvider.dispose);
    addTearDown(budgetProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: categoryProvider),
          ChangeNotifierProvider.value(value: budgetProvider),
        ],
        child: const MaterialApp(home: BudgetsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Budget'), findsOneWidget);
    expect(find.text('500'), findsOneWidget,
        reason: 'the amount field must be pre-filled from the existing '
            'budget');

    await tester.enterText(find.byType(TextField), '750');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'saving an edit must not throw');
    expect(find.text('Edit Budget'), findsNothing,
        reason: 'dialog should have closed on a successful save, not '
            'stayed open showing a "Could not save" error');
    expect(budgetProvider.error, isNull);
    expect(budgetProvider.budgets.first.amount, 750.0);
  });
}
