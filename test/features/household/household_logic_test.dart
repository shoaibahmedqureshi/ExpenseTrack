import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/categories/domain/entities/category.dart';
import 'package:outlay/features/expenses/domain/entities/expense.dart';
import 'package:outlay/features/expenses/domain/repositories/expense_repository.dart';
import 'package:outlay/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:outlay/features/expenses/domain/usecases/manage_expense_usecase.dart';
import 'package:outlay/features/expenses/presentation/providers/expense_provider.dart';
import 'package:outlay/features/household/data/household_repository.dart';
import 'package:outlay/features/household/domain/household_calculator.dart';
import 'package:outlay/features/household/domain/household_models.dart';
import 'package:outlay/features/household/presentation/providers/household_provider.dart';

Category _cat(String name) => Category(id: name.hashCode, name: name, icon: Icons.circle, color: Colors.blue);

Expense _exp(String category, double amount, DateTime date, {TransactionType type = TransactionType.expense}) =>
    Expense(title: 'x', amount: amount, date: date, type: type, category: _cat(category));

HouseholdMember _member(String id, {bool sharing = true, bool owner = false, Map<String, int> cats = const {}}) => HouseholdMember(
    userId: id, name: id, email: '$id@x.com', isOwner: owner, sharing: sharing, categories: sharing ? cats : const {});

HouseholdOverview _overview(List<HouseholdMember> members, {List<HouseholdBudget> budgets = const []}) =>
    HouseholdOverview(month: DateTime(2026, 10), members: members, budgets: budgets);

void main() {
  group('HouseholdCalculator', () {
    final o = _overview([
      _member('me', owner: true, cats: {'Food': 30000, 'Rent': 90000}),
      _member('ann', cats: {'Food': 12050, 'Fun': 5000}),
      _member('bob', sharing: false),
    ], budgets: const [
      HouseholdBudget(category: null, amountCents: 200000),
      HouseholdBudget(category: 'Food', amountCents: 40000),
      HouseholdBudget(category: 'Travel', amountCents: 10000),
    ]);

    test('totals only what the sharing members spent', () {
      expect(HouseholdCalculator.totalCents(o), 30000 + 90000 + 12050 + 5000);
    });

    test('a member who is not sharing is ignored even if figures somehow arrive for them', () {
      const leaky = HouseholdMember(userId: 'x', name: 'x', email: 'x@x.com', isOwner: false, sharing: false, categories: {'Food': 99999});
      final withLeak = _overview([_member('me', cats: {'Food': 100}), leaky]);
      expect(HouseholdCalculator.totalCents(withLeak), 100);
      expect(HouseholdCalculator.byCategory(withLeak), {'Food': 100});
    });

    test('merges categories across members', () {
      expect(HouseholdCalculator.byCategory(o), {'Food': 42050, 'Rent': 90000, 'Fun': 5000});
    });

    test('counts who is and is not sharing', () {
      expect(HouseholdCalculator.sharingCount(o), 2);
      expect(HouseholdCalculator.notSharingCount(o), 1);
    });

    test('overall budget status', () {
      final s = HouseholdCalculator.overall(o)!;
      expect(s.budgetCents, 200000);
      expect(s.spentCents, 137050);
      expect(s.remainingCents, 62950);
      expect(s.isOver, isFalse);
      expect(s.percentUsed, 69);
      expect(s.fraction, closeTo(0.685, 0.001));
    });

    test('no overall budget means no overall status', () {
      expect(HouseholdCalculator.overall(_overview([_member('me', cats: {'Food': 1})])), isNull);
    });

    test('spending past the budget is flagged, and the bar stops at full', () {
      final s = const BudgetStatus(budgetCents: 10000, spentCents: 12500);
      expect(s.isOver, isTrue);
      expect(s.remainingCents, -2500);
      expect(s.fraction, 1.0);
      expect(s.percentUsed, 125);
    });

    test('exactly on budget is not over', () {
      expect(const BudgetStatus(budgetCents: 10000, spentCents: 10000).isOver, isFalse);
    });

    test('a zero budget never divides by zero', () {
      const s = BudgetStatus(budgetCents: 0, spentCents: 500);
      expect(s.fraction, 0);
      expect(s.percentUsed, 0);
    });

    test('category lines list spending first, then budgeted categories with no spending', () {
      final lines = HouseholdCalculator.categoryLines(o);
      expect(lines.map((l) => l.category), ['Rent', 'Food', 'Fun', 'Travel']);
      expect(lines[1].budgetCents, 40000);
      expect(lines[1].status!.isOver, isTrue); // 420.50 against a 400 budget
      expect(lines[0].status, isNull); // Rent has no budget
      expect(lines[3].spentCents, 0);
      expect(lines[3].status!.spentCents, 0);
    });

    test('an empty household has nothing to show', () {
      final empty = HouseholdOverview.empty(DateTime(2026, 10));
      expect(HouseholdCalculator.totalCents(empty), 0);
      expect(HouseholdCalculator.categoryLines(empty), isEmpty);
    });
  });

  group('HouseholdOverview.fromJson', () {
    test('parses members and budgets, turning amounts into cents', () {
      final o = HouseholdOverview.fromJson({
        'month': '2026-10-01',
        'members': [
          {'user_id': 'a', 'name': 'Ann', 'email': 'a@x.com', 'is_owner': true, 'sharing': true,
           'categories': [{'category': 'Food', 'spent': 120.5}, {'category': 'Rent', 'spent': 900}]},
          {'user_id': 'b', 'name': 'Bob', 'email': 'b@x.com', 'is_owner': false, 'sharing': false, 'categories': []},
        ],
        'budgets': [{'category': null, 'amount': 5000}, {'category': 'Food', 'amount': 1500.56}],
      });
      expect(o.month, DateTime(2026, 10));
      expect(o.members.first.categories, {'Food': 12050, 'Rent': 90000});
      expect(o.members.first.totalCents, 102050);
      expect(o.members.last.sharing, isFalse);
      expect(o.budgets.map((b) => b.amountCents), [500000, 150056]);
      expect(o.budgets.first.category, isNull);
      expect(o.member('b')!.name, 'Bob');
      expect(o.member('zzz'), isNull);
    });
  });

  group('SummaryBuilder', () {
    final now = DateTime(2026, 10, 20);

    test('shares monthly category totals for this month and the two before', () {
      final s = SummaryBuilder.build([
        _exp('Food', 10, DateTime(2026, 10, 1)),
        _exp('Food', 5.5, DateTime(2026, 10, 19)),
        _exp('Rent', 900, DateTime(2026, 10, 3)),
        _exp('Food', 40, DateTime(2026, 9, 30)),
        _exp('Food', 25, DateTime(2026, 8, 1)),
        _exp('Food', 99, DateTime(2026, 7, 31)), // too old
      ], now);
      expect(s.from, DateTime(2026, 8));
      expect(s.rows.map((r) => '${r.month.month}:${r.category}:${r.cents}').toList(),
          ['8:Food:2500', '9:Food:4000', '10:Rent:90000', '10:Food:1550']);
    });

    test('rows come out oldest month first, biggest category first', () {
      final s = SummaryBuilder.build([
        _exp('Food', 10, DateTime(2026, 10, 1)),
        _exp('Rent', 900, DateTime(2026, 10, 2)),
        _exp('Food', 40, DateTime(2026, 9, 2)),
      ], now);
      expect(s.rows.map((r) => '${r.month.month}:${r.category}').toList(), ['9:Food', '10:Rent', '10:Food']);
    });

    test('income and future-dated entries are left out', () {
      final s = SummaryBuilder.build([
        _exp('Salary', 5000, DateTime(2026, 10, 1), type: TransactionType.income),
        _exp('Food', 10, DateTime(2026, 11, 1)),
        _exp('Food', 7, DateTime(2026, 10, 5)),
      ], now);
      expect(s.rows.single.cents, 700);
    });

    test('amounts are added in whole cents, with no floating-point drift', () {
      final s = SummaryBuilder.build([for (var i = 0; i < 10; i++) _exp('Food', 0.1, DateTime(2026, 10, 2))], now);
      expect(s.rows.single.cents, 100);
    });

    test('names are trimmed and shortened, and an empty name becomes Other', () {
      final long = 'A' * 60;
      final s = SummaryBuilder.build([_exp('  ', 5, DateTime(2026, 10, 2)), _exp(long, 6, DateTime(2026, 10, 2))], now);
      expect(s.rows.map((r) => r.category).toSet(), {'Other', 'A' * 40});
    });

    test('nothing to share gives an empty list but still says where to start from', () {
      final s = SummaryBuilder.build(const [], now);
      expect(s.rows, isEmpty);
      expect(s.from, DateTime(2026, 8));
    });

    test('an unusually long list of categories is folded so the server limit is never hit', () {
      final s = SummaryBuilder.build([for (var i = 0; i < 150; i++) _exp('Cat $i', 1.0 + i, DateTime(2026, 10, 2))], now);
      expect(s.rows.length, lessThanOrEqualTo(60));
      final total = s.rows.fold<int>(0, (a, r) => a + r.cents);
      expect(total, [for (var i = 0; i < 150; i++) ((1.0 + i) * 100).round()].reduce((a, b) => a + b));
      expect(s.rows.any((r) => r.category == 'Other'), isTrue);
    });

    test('rows serialise as first-of-month, category and a two-decimal amount', () {
      final s = SummaryBuilder.build([_exp('Food', 12.34, DateTime(2026, 10, 9))], now);
      expect(s.rows.single.toJson(), {'month': '2026-10-01', 'category': 'Food', 'spent': 12.34});
    });
  });

  group('HouseholdProvider', () {
    late _FakeHouseholdRepo repo;
    late _FakeExpenses expensesRepo;
    late ExpenseProvider expenses;
    late DateTime now;

    HouseholdProvider make() {
      final p = HouseholdProvider(
        repository: repo,
        getCurrentUserId: () => 'me',
        now: () => now,
        publishDelay: const Duration(milliseconds: 20),
      )..attachExpenses(expenses);
      addTearDown(p.dispose);
      return p;
    }

    setUp(() {
      now = DateTime(2026, 10, 20);
      repo = _FakeHouseholdRepo();
      expensesRepo = _FakeExpenses([_exp('Food', 10, DateTime(2026, 10, 5))]);
      expenses = ExpenseProvider(getExpenses: GetExpensesUsecase(expensesRepo), manageExpense: ManageExpenseUsecase(expensesRepo));
    });

    test('loads the household for the family and month', () async {
      repo.members = [_member('me', sharing: false, owner: true)];
      final p = make();
      await p.load(7);
      expect(repo.overviewCalls.single, (7, DateTime(2026, 10)));
      expect(p.me!.userId, 'me');
      expect(p.isOwner, isTrue);
      expect(p.isSharing, isFalse);
      expect(p.hasLoaded, isTrue);
    });

    test('turning sharing on shares totals straight away, then reloads', () async {
      await expenses.loadAll();
      repo.members = [_member('me', sharing: false)];
      final p = make();
      await p.load(7);
      repo.onSetSharing = (on) => repo.members = [_member('me', sharing: on, cats: on ? {'Food': 1000} : {})];
      expect(await p.setSharing(true), isTrue);
      expect(repo.calls, ['sharing:7:true', 'publish:7:2026-08-01:1']);
      expect(p.isSharing, isTrue);
      expect(p.me!.totalCents, 1000);
    });

    test('turning sharing off shares nothing', () async {
      repo.members = [_member('me', sharing: true)];
      final p = make();
      await p.load(7);
      expect(await p.setSharing(false), isTrue);
      expect(repo.calls, ['sharing:7:false']);
    });

    test('nothing is published unless sharing is on', () async {
      await expenses.loadAll();
      repo.members = [_member('me', sharing: false)];
      final p = make();
      await p.load(7);
      await p.publishNow();
      expect(repo.calls.where((c) => c.startsWith('publish')), isEmpty);
    });

    test('while sharing, a change to the expenses is re-shared after a short pause', () async {
      repo.members = [_member('me', sharing: true)];
      final p = make();
      await p.load(7);
      await expenses.loadAll(); // the expense list changed
      expect(repo.calls.where((c) => c.startsWith('publish')), isEmpty); // not yet
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(repo.calls.where((c) => c.startsWith('publish')), hasLength(1));
    });

    test('several quick changes are shared once', () async {
      repo.members = [_member('me', sharing: true)];
      final p = make();
      await p.load(7);
      for (var i = 0; i < 4; i++) {
        await expenses.loadAll();
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(repo.calls.where((c) => c.startsWith('publish')), hasLength(1));
    });

    test('changes are not shared when sharing is off', () async {
      repo.members = [_member('me', sharing: false)];
      final p = make();
      await p.load(7);
      await expenses.loadAll();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(repo.calls.where((c) => c.startsWith('publish')), isEmpty);
    });

    test('syncFor learns the sharing state and refreshes what is shared', () async {
      await expenses.loadAll();
      repo.members = [_member('me', sharing: true)];
      final p = make();
      await p.syncFor(7);
      expect(repo.calls.where((c) => c.startsWith('publish')), hasLength(1));
    });

    test('syncFor with no family clears everything', () async {
      repo.members = [_member('me')];
      final p = make();
      await p.load(7);
      await p.syncFor(null);
      expect(p.familyId, isNull);
      expect(p.overview.members, isEmpty);
    });

    test('a refused budget change reports the server message', () async {
      repo.members = [_member('me')];
      final p = make();
      await p.load(7);
      repo.failWith = Exception('Only the family admin can set the budget');
      expect(await p.setBudget(null, 50000), isFalse);
      expect(p.error, 'Only the family admin can set the budget');
    });

    test('setting and clearing a budget call the server with cents', () async {
      repo.members = [_member('me', owner: true)];
      final p = make();
      await p.load(7);
      await p.setBudget('Food', 150056);
      await p.clearBudget('Food');
      expect(repo.calls, ['budget:7:Food:150056', 'clear:7:Food']);
    });

    test('month navigation stops at the current month', () async {
      repo.members = [_member('me')];
      final p = make();
      await p.load(7);
      expect(p.canGoForward, isFalse);
      await p.nextMonth();
      expect(p.month, DateTime(2026, 10));
      await p.previousMonth();
      expect(p.month, DateTime(2026, 9));
      expect(p.canGoForward, isTrue);
      await p.nextMonth();
      expect(p.month, DateTime(2026, 10));
    });

    test('the current month is kept for the dashboard while another month is on screen', () async {
      repo.members = [_member('me', cats: {'Food': 500})];
      final p = make();
      await p.syncFor(7);
      expect(p.current.members.single.totalCents, 500);
      repo.members = [_member('me', cats: {'Food': 99999})]; // what September looks like
      await p.previousMonth();
      expect(p.month, DateTime(2026, 9));
      expect(p.overview.members.single.totalCents, 99999);
      expect(p.current.members.single.totalCents, 500); // unchanged
    });

    test('syncFor always loads the current month, even if a past month was left open', () async {
      repo.members = [_member('me')];
      final p = make();
      await p.load(7);
      await p.previousMonth();
      await p.syncFor(7);
      expect(p.month, DateTime(2026, 10));
      expect(repo.overviewCalls.last, (7, DateTime(2026, 10)));
    });

    test('a budget saved for the current month shows up in current straight away', () async {
      repo.members = [_member('me', owner: true)];
      final p = make();
      await p.syncFor(7);
      repo.budgets = [const HouseholdBudget(category: null, amountCents: 100000)];
      await p.setBudget(null, 100000);
      expect(p.current.budgets.single.amountCents, 100000);
    });

    test('a budget saved while looking at a past month does not replace the current figures', () async {
      repo.members = [_member('me', owner: true, cats: {'Food': 100})];
      final p = make();
      await p.syncFor(7);
      await p.previousMonth();
      repo.members = [_member('me', owner: true, cats: {'Food': 7777})];
      await p.setBudget(null, 100000);
      expect(p.current.members.single.totalCents, 100);
    });

    test('clear (sign-out) forgets the family and the figures', () async {
      repo.members = [_member('me', cats: {'Food': 100})];
      final p = make();
      await p.load(7);
      p.clear();
      expect(p.familyId, isNull);
      expect(p.overview.members, isEmpty);
      expect(p.current.members, isEmpty);
      expect(p.hasLoaded, isFalse);
    });
  });
}

class _FakeExpenses implements ExpenseRepository {
  _FakeExpenses(this.items);
  final List<Expense> items;
  @override
  Future<List<Expense>> getAll() async => items;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeHouseholdRepo implements HouseholdRepository {
  List<HouseholdMember> members = [];
  List<HouseholdBudget> budgets = [];
  Object? failWith;
  void Function(bool)? onSetSharing;
  final calls = <String>[];
  final overviewCalls = <(int, DateTime)>[];

  void _fail() {
    if (failWith != null) throw failWith!;
  }

  @override
  Future<HouseholdOverview> overview(int familyId, DateTime month) async {
    overviewCalls.add((familyId, month));
    return HouseholdOverview(month: DateTime(month.year, month.month), members: members, budgets: budgets);
  }

  @override
  Future<void> setSharing(int familyId, bool enabled) async {
    _fail();
    calls.add('sharing:$familyId:$enabled');
    onSetSharing?.call(enabled);
  }

  @override
  Future<void> publish(int familyId, SharedSummary summary) async {
    _fail();
    final d = summary.from;
    calls.add('publish:$familyId:${d.year}-${d.month.toString().padLeft(2, '0')}-01:${summary.rows.length}');
  }

  @override
  Future<void> setBudget(int familyId, String? category, int cents) async {
    _fail();
    calls.add('budget:$familyId:$category:$cents');
  }

  @override
  Future<void> clearBudget(int familyId, String? category) async {
    _fail();
    calls.add('clear:$familyId:$category');
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
