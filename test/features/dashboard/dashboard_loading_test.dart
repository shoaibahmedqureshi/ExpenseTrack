import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:outlay/features/auth/domain/entities/user_profile.dart';
import 'package:outlay/features/auth/domain/repositories/auth_repository.dart';
import 'package:outlay/features/auth/presentation/providers/auth_provider.dart';
import 'package:outlay/features/budgets/domain/entities/budget.dart';
import 'package:outlay/features/budgets/domain/repositories/budget_repository.dart';
import 'package:outlay/features/budgets/domain/usecases/get_budgets_usecase.dart';
import 'package:outlay/features/budgets/domain/usecases/manage_budget_usecase.dart';
import 'package:outlay/features/budgets/presentation/providers/budget_provider.dart';
import 'package:outlay/features/categories/data/models/category_model.dart';
import 'package:outlay/features/categories/domain/entities/category.dart';
import 'package:outlay/features/categories/domain/repositories/category_repository.dart';
import 'package:outlay/features/categories/presentation/providers/category_provider.dart';
import 'package:outlay/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:outlay/features/expenses/domain/entities/expense.dart';
import 'package:outlay/features/expenses/domain/repositories/expense_repository.dart';
import 'package:outlay/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:outlay/features/expenses/domain/usecases/manage_expense_usecase.dart';
import 'package:outlay/features/expenses/presentation/providers/expense_provider.dart';
import 'package:outlay/features/sync/sync_service.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();
  @override
  UserProfile? get currentUser => const UserProfile(id: '1', email: 'a@b.com');
  @override
  Future<UserProfile> signUpWithEmail(String e, String p, String n) async =>
      currentUser!;
  @override
  Future<UserProfile> signInWithEmail(String e, String p) async =>
      currentUser!;
  @override
  Future<UserProfile> signInWithGoogle() async => currentUser!;
  @override
  Future<UserProfile> signInWithApple() async => currentUser!;
  @override
  Future<void> signOut() async {}
  @override
  Future<void> updateProfile({String? name, String? currency}) async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
}

/// A repository whose getAll() only resolves when the test explicitly
/// completes [gate] — this is what lets the test observe the exact "still
/// loading" window deterministically, without depending on any real
/// database's timing (or a test-isolate FFI hang, which is what a real
/// sqflite_common_ffi-backed provider ran into here).
class _GatedExpenseRepository implements ExpenseRepository {
  final Completer<List<Expense>> gate = Completer<List<Expense>>();

  @override
  Future<List<Expense>> getAll() => gate.future;
  @override
  Future<List<Expense>> getByDateRange(DateTime from, DateTime to) =>
      gate.future;
  @override
  Future<List<Expense>> getByCategory(int categoryId) => gate.future;
  @override
  Future<Expense> getById(int id) async => (await gate.future).first;
  @override
  Future<int> insert(Expense expense) async => 1;
  @override
  Future<void> update(Expense expense) async {}
  @override
  Future<void> delete(int id) async {}
  @override
  Future<double> getTotalByType(TransactionType type) async => 0;
}

/// DashboardScreen's initState also loads BudgetProvider and
/// CategoryProvider (Consumer3, not just ExpenseProvider) — empty-but-real
/// fakes are all it needs since this file only asserts on loading/sync
/// behavior, not budget or category content.
class _EmptyBudgetRepository implements BudgetRepository {
  @override
  Future<List<Budget>> getByMonth(DateTime month) async => [];
  @override
  Future<int> insert(Budget budget) async => 1;
  @override
  Future<void> update(Budget budget) async {}
  @override
  Future<void> delete(int id) async {}
}

class _EmptyCategoryRepository implements CategoryRepository {
  @override
  Future<List<Category>> getAll() async => [];
  @override
  Future<Category> getById(int id) async => throw UnimplementedError();
  @override
  Future<int> insert(Category category) async => 1;
  @override
  Future<void> update(Category category) async {}
  @override
  Future<void> delete(int id) async {}
}

void main() {
  testWidgets(
      'CRITICAL: Dashboard shows a loader (not a zero-balance/empty '
      'dashboard) until the first ExpenseProvider.loadAll() completes, then '
      'shows real content', (tester) async {
    final gatedRepo = _GatedExpenseRepository();
    final expenseProvider = ExpenseProvider(
      getExpenses: GetExpensesUsecase(gatedRepo),
      manageExpense: ManageExpenseUsecase(gatedRepo),
    );
    final authProvider = AuthProvider(_FakeAuthRepository());
    final budgetProvider = BudgetProvider(
      getBudgets: GetBudgetsUsecase(_EmptyBudgetRepository()),
      manageBudget: ManageBudgetUsecase(_EmptyBudgetRepository()),
      getExpenses: GetExpensesUsecase(_GatedExpenseRepository()..gate.complete([])),
    );
    final categoryProvider = CategoryProvider(_EmptyCategoryRepository());
    addTearDown(expenseProvider.dispose);
    addTearDown(authProvider.dispose);
    addTearDown(budgetProvider.dispose);
    addTearDown(categoryProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: expenseProvider),
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: budgetProvider),
          ChangeNotifierProvider.value(value: categoryProvider),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    // initState's postFrameCallback runs after this first frame; pump once
    // more so ExpenseProvider.loadAll() actually starts (and blocks on the
    // gate) before we assert anything.
    await tester.pump();

    // Still "loading": the gate hasn't been completed yet, so
    // hasLoadedOnce must still be false.
    expect(find.byType(CircularProgressIndicator), findsOneWidget,
        reason: 'must show a loader before the first load completes, not '
            'a zero-value dashboard');
    expect(find.text('Balance this period'), findsNothing,
        reason: 'real dashboard content must not render yet');

    // Now let the "DB query" resolve.
    gatedRepo.gate.complete([
      Expense(
        title: 'Groceries',
        amount: 42.0,
        // Dashboard's month view defaults to the real current month, so a
        // hardcoded date here would silently fall outside it once real
        // time moves past that month.
        date: DateTime(DateTime.now().year, DateTime.now().month, 5),
        type: TransactionType.expense,
        category: CategoryModel(
          id: 1,
          name: 'Food',
          icon: Icons.restaurant,
          color: Colors.red,
        ),
      ),
    ]);
    // A few bounded pumps to let the completed Future's callbacks and the
    // resulting rebuild flush — not pumpAndSettle(): the loader itself is
    // an indeterminate CircularProgressIndicator, which animates forever
    // by design, so pumpAndSettle would hang waiting for an animation that
    // never stops if it were still (incorrectly) showing.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'loader must be gone once real data has loaded');
    expect(find.text('Balance this period'), findsOneWidget);
    // The default unsized test surface is short enough that the
    // transaction tile renders below the fold — skipOffstage: false
    // because this assertion is about the real data having rendered at
    // all, not about it being scroll-visible on an arbitrary viewport.
    expect(find.text('Groceries', skipOffstage: false), findsOneWidget,
        reason: 'the real expense must actually be showing now');
  });

  testWidgets(
      'CRITICAL: once data has loaded, a background sync must show a '
      'subtle top indicator WITHOUT blanking the already-visible dashboard '
      '— the full-screen spinner is only for the very first load with '
      'nothing to show yet; a later sync (the 30s periodic timer, '
      'connectivity changes, etc.) must never hide already-loaded content '
      'behind a spinner again', (tester) async {
    final gatedRepo = _GatedExpenseRepository();
    final expenseProvider = ExpenseProvider(
      getExpenses: GetExpensesUsecase(gatedRepo),
      manageExpense: ManageExpenseUsecase(gatedRepo),
    );
    final authProvider = AuthProvider(_FakeAuthRepository());
    final budgetProvider = BudgetProvider(
      getBudgets: GetBudgetsUsecase(_EmptyBudgetRepository()),
      manageBudget: ManageBudgetUsecase(_EmptyBudgetRepository()),
      getExpenses: GetExpensesUsecase(_GatedExpenseRepository()..gate.complete([])),
    );
    final categoryProvider = CategoryProvider(_EmptyCategoryRepository());
    addTearDown(expenseProvider.dispose);
    addTearDown(authProvider.dispose);
    addTearDown(budgetProvider.dispose);
    addTearDown(categoryProvider.dispose);
    addTearDown(() => SyncService.isSyncingNotifier.value = false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: expenseProvider),
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: budgetProvider),
          ChangeNotifierProvider.value(value: categoryProvider),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();
    gatedRepo.gate.complete(const []);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Sanity check: fully loaded, loader gone, exactly like the test above.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Balance this period'), findsOneWidget);

    // Now simulate a sync starting — exactly what SyncService.run() does.
    SyncService.isSyncingNotifier.value = true;
    await tester.pump();

    expect(find.text('Balance this period'), findsOneWidget,
        reason: 'already-loaded content must stay visible during a '
            'background sync — the screen must never go blank again once '
            'there is real data to show');
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'the full-screen spinner must not reappear once data has '
            'loaded once');
    expect(find.byType(LinearProgressIndicator), findsOneWidget,
        reason: 'a subtle top indicator communicates the background sync '
            'instead of hiding the dashboard');

    // And the indicator must go away again once the sync finishes, with
    // the dashboard still showing throughout.
    SyncService.isSyncingNotifier.value = false;
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing,
        reason: 'top indicator must clear once sync finishes');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Balance this period'), findsOneWidget,
        reason: 'content was visible the whole time and remains visible');
  });
}
