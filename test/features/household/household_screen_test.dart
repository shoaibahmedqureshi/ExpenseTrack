import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/household/data/household_repository.dart';
import 'package:outlay/features/household/domain/household_calculator.dart';
import 'package:outlay/features/household/domain/household_models.dart';
import 'package:outlay/features/household/presentation/providers/household_provider.dart';
import 'package:outlay/features/household/presentation/screens/household_screen.dart';
import 'package:provider/provider.dart';

class _Repo implements HouseholdRepository {
  List<HouseholdMember> members = [];
  List<HouseholdBudget> budgets = [];
  Object? failOverview;
  Object? failWrite;
  final calls = <String>[];
  final months = <DateTime>[];

  @override
  Future<HouseholdOverview> overview(int familyId, DateTime month) async {
    months.add(month);
    if (failOverview != null) throw failOverview!;
    return HouseholdOverview(month: DateTime(month.year, month.month), members: members, budgets: budgets);
  }

  @override
  Future<void> setSharing(int familyId, bool enabled) async {
    if (failWrite != null) throw failWrite!;
    calls.add('sharing:$enabled');
    members = [for (final m in members) m.userId == 'me' ? _m('me', sharing: enabled, owner: m.isOwner, cats: enabled ? m.categories : const {}) : m];
  }

  @override
  Future<void> publish(int familyId, SharedSummary summary) async {}

  @override
  Future<void> setBudget(int familyId, String? category, int cents) async {
    if (failWrite != null) throw failWrite!;
    calls.add('budget:$category:$cents');
    budgets = [...budgets.where((b) => b.category != category), HouseholdBudget(category: category, amountCents: cents)];
  }

  @override
  Future<void> clearBudget(int familyId, String? category) async {
    if (failWrite != null) throw failWrite!;
    calls.add('clear:$category');
    budgets = budgets.where((b) => b.category != category).toList();
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

HouseholdMember _m(String id, {bool sharing = true, bool owner = false, Map<String, int> cats = const {}, String? name}) => HouseholdMember(
    userId: id, name: name ?? id, email: '$id@x.com', isOwner: owner, sharing: sharing, categories: sharing ? cats : const {});

Future<_Repo> _open(WidgetTester t, {required bool owner, bool meSharing = true, List<HouseholdBudget> budgets = const []}) async {
  final repo = _Repo()
    ..members = [
      _m('me', owner: owner, sharing: meSharing, cats: {'Food': 30000, 'Rent': 90000}, name: 'Me'),
      _m('ann', owner: !owner, cats: {'Food': 12050}, name: 'Ann Lee'),
      _m('bob', sharing: false, name: 'Bob'),
    ]
    ..budgets = budgets;
  final provider = HouseholdProvider(repository: repo, getCurrentUserId: () => 'me', now: () => DateTime(2026, 10, 20));
  addTearDown(provider.dispose);
  await t.binding.setSurfaceSize(const Size(400, 1600));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(ChangeNotifierProvider.value(value: provider, child: const MaterialApp(home: HouseholdScreen(familyId: 7))));
  await t.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('shows what the household has spent, from the people who share', (t) async {
    await _open(t, owner: true);
    expect(find.text('Household spending'), findsOneWidget);
    expect(find.text('\$1,320.50'), findsOneWidget); // 300 + 900 + 120.50
    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('with a budget it says how much is left and how much is used', (t) async {
    await _open(t, owner: true, budgets: const [HouseholdBudget(category: null, amountCents: 200000)]);
    expect(find.text('\$679.50 left of \$2,000.00 (66% used)'), findsOneWidget);
  });

  testWidgets('over budget is called out', (t) async {
    await _open(t, owner: true, budgets: const [HouseholdBudget(category: null, amountCents: 100000)]);
    expect(find.text('\$320.50 over the \$1,000.00 budget'), findsOneWidget);
  });

  testWidgets('with no budget it says so', (t) async {
    await _open(t, owner: true);
    expect(find.text('No monthly budget set yet'), findsOneWidget);
  });

  testWidgets('only the admin sees the buttons for changing the budget', (t) async {
    await _open(t, owner: true);
    expect(find.text('Set monthly budget'), findsOneWidget);
    expect(find.text('Add a category budget'), findsOneWidget);
  });

  testWidgets('an ordinary member sees the budget but cannot change it', (t) async {
    await _open(t, owner: false, budgets: const [HouseholdBudget(category: null, amountCents: 200000)]);
    expect(find.textContaining('left of'), findsOneWidget);
    expect(find.text('Set monthly budget'), findsNothing);
    expect(find.text('Change budget'), findsNothing);
    expect(find.text('Add a category budget'), findsNothing);
  });

  testWidgets('the admin sets the monthly budget', (t) async {
    final repo = await _open(t, owner: true);
    await t.tap(find.text('Set monthly budget'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '3000');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(repo.calls, ['budget:null:300000']);
    expect(find.text('Budget saved'), findsOneWidget);
    expect(find.textContaining('left of \$3,000.00'), findsOneWidget);
  });

  testWidgets('an amount that is not a number is refused in the dialog', (t) async {
    final repo = await _open(t, owner: true);
    await t.tap(find.text('Set monthly budget'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'lots');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(find.text('Enter an amount greater than zero'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('the admin can remove the budget', (t) async {
    final repo = await _open(t, owner: true, budgets: const [HouseholdBudget(category: null, amountCents: 200000)]);
    await t.tap(find.text('Change budget'));
    await t.pumpAndSettle();
    await t.tap(find.text('Remove'));
    await t.pumpAndSettle();
    expect(repo.calls, ['clear:null']);
    expect(find.text('Budget removed'), findsOneWidget);
    expect(find.text('No monthly budget set yet'), findsOneWidget);
  });

  testWidgets('a server refusal when saving is shown', (t) async {
    final repo = await _open(t, owner: true);
    repo.failWrite = Exception('Only the family admin can set the budget');
    await t.tap(find.text('Set monthly budget'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '100');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(find.text('Only the family admin can set the budget'), findsWidgets);
  });

  testWidgets('categories show spending, and a category budget shows progress and any overspend', (t) async {
    await _open(t, owner: true, budgets: const [HouseholdBudget(category: 'Food', amountCents: 40000)]);
    expect(find.text('By category'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('\$900.00'), findsOneWidget);
    expect(find.text('\$420.50 of \$400.00'), findsOneWidget);
    expect(find.text('\$20.50 over'), findsOneWidget);
  });

  testWidgets('the admin can set a budget for one category by tapping it', (t) async {
    final repo = await _open(t, owner: true);
    await t.tap(find.text('Rent'));
    await t.pumpAndSettle();
    expect(find.text('Rent budget'), findsOneWidget);
    await t.enterText(find.byType(TextField), '950');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(repo.calls, ['budget:Rent:95000']);
  });

  testWidgets('a member tapping a category changes nothing', (t) async {
    await _open(t, owner: false);
    await t.tap(find.text('Rent'));
    await t.pumpAndSettle();
    expect(find.text('Rent budget'), findsNothing);
  });

  testWidgets('adding a category budget offers the categories already in use', (t) async {
    final repo = await _open(t, owner: true);
    await t.tap(find.text('Add a category budget'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, 'Food'), findsOneWidget);
    await t.tap(find.widgetWithText(ActionChip, 'Rent'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '800');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(repo.calls, ['budget:Rent:80000']);
  });

  testWidgets('sharing is a switch with a plain explanation, and turning it on is confirmed', (t) async {
    final repo = await _open(t, owner: false, meSharing: false);
    expect(t.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    expect(find.textContaining('never individual expenses'), findsOneWidget);
    expect(find.textContaining('Off by default'), findsOneWidget);
    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    expect(repo.calls, ['sharing:true']);
    expect(find.text('Sharing is on'), findsOneWidget);
    expect(t.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
  });

  testWidgets('turning sharing off says the shared totals were removed', (t) async {
    final repo = await _open(t, owner: false, meSharing: true);
    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    expect(repo.calls, ['sharing:false']);
    expect(find.text('Sharing is off. Your totals were removed.'), findsOneWidget);
  });

  testWidgets('members who are not sharing show no figures, and the privacy note appears', (t) async {
    await _open(t, owner: true);
    expect(find.text('You · Admin'), findsOneWidget);
    expect(find.text('Ann Lee'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Not sharing'), findsOneWidget);
    expect(find.text('Sharing monthly totals'), findsNWidgets(2));
    expect(find.textContaining('Only people who share their monthly totals are counted'), findsOneWidget);
  });

  testWidgets('the month can be changed back, but not past the current month', (t) async {
    final repo = await _open(t, owner: true);
    expect(t.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull);
    await t.tap(find.byTooltip('Previous month'));
    await t.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    expect(repo.months.last, DateTime(2026, 9));
    expect(t.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNotNull);
  });

  testWidgets('a failure to load is shown instead of a blank screen', (t) async {
    final repo = _Repo()..failOverview = Exception('You are not a member of this family');
    final provider = HouseholdProvider(repository: repo, getCurrentUserId: () => 'me', now: () => DateTime(2026, 10, 20));
    addTearDown(provider.dispose);
    await t.pumpWidget(ChangeNotifierProvider.value(value: provider, child: const MaterialApp(home: HouseholdScreen(familyId: 7))));
    await t.pumpAndSettle();
    expect(find.text('You are not a member of this family'), findsOneWidget);
  });

  testWidgets('nothing is shown for people who are not sharing when nobody shares', (t) async {
    final repo = _Repo()..members = [_m('me', owner: true, sharing: false), _m('ann', sharing: false)];
    final provider = HouseholdProvider(repository: repo, getCurrentUserId: () => 'me', now: () => DateTime(2026, 10, 20));
    addTearDown(provider.dispose);
    await t.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(ChangeNotifierProvider.value(value: provider, child: const MaterialApp(home: HouseholdScreen(familyId: 7))));
    await t.pumpAndSettle();
    expect(find.text('\$0.00'), findsOneWidget);
    expect(HouseholdCalculator.totalCents(provider.overview), 0);
    expect(find.text('Not sharing'), findsNWidgets(2));
  });
}
