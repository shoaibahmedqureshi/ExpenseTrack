import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/dashboard/presentation/widgets/household_summary_card.dart';
import 'package:outlay/features/household/data/household_repository.dart';
import 'package:outlay/features/household/domain/household_models.dart';
import 'package:outlay/features/household/presentation/providers/household_provider.dart';
import 'package:provider/provider.dart';

class _Repo implements HouseholdRepository {
  List<HouseholdMember> members = [];
  List<HouseholdBudget> budgets = [];
  @override
  Future<HouseholdOverview> overview(int familyId, DateTime month) async =>
      HouseholdOverview(month: DateTime(month.year, month.month), members: members, budgets: budgets);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

HouseholdMember _m(String id, {bool sharing = true, bool owner = false, Map<String, int> cats = const {}}) =>
    HouseholdMember(userId: id, name: id, email: '$id@x.com', isOwner: owner, sharing: sharing, categories: sharing ? cats : const {});

Future<HouseholdProvider> _pump(
  WidgetTester t, {
  required List<HouseholdMember> members,
  List<HouseholdBudget> budgets = const [],
  bool loaded = true,
  VoidCallback? onTap,
}) async {
  final repo = _Repo()
    ..members = members
    ..budgets = budgets;
  final p = HouseholdProvider(repository: repo, getCurrentUserId: () => 'me', now: () => DateTime(2026, 10, 20));
  addTearDown(p.dispose);
  if (loaded) await t.runAsync(() => p.syncFor(7));
  await t.pumpWidget(ChangeNotifierProvider.value(
    value: p,
    child: MaterialApp(home: Scaffold(body: HouseholdSummaryCard(onTap: onTap ?? () {}))),
  ));
  await t.pumpAndSettle();
  return p;
}

final _team = [
  _m('me', owner: true, cats: {'Food': 30000, 'Rent': 90000}),
  _m('ann', cats: {'Food': 12050}),
  _m('bob', sharing: false),
];

void main() {
  testWidgets('hidden for someone with no family', (t) async {
    await _pump(t, members: _team, loaded: false);
    expect(find.textContaining('Household budget'), findsNothing);
  });

  testWidgets('hidden when there is no budget and nobody shares yet', (t) async {
    await _pump(t, members: [_m('me', owner: true, sharing: false), _m('ann', sharing: false)]);
    expect(find.textContaining('Household budget'), findsNothing);
  });

  testWidgets('with a budget it shows what is left, the bar and who is sharing', (t) async {
    await _pump(t, members: _team, budgets: const [HouseholdBudget(category: null, amountCents: 200000)]);
    expect(find.text('Household budget · Oct'), findsOneWidget);
    expect(find.text('\$679.50 left'), findsOneWidget);
    expect(find.text('\$1,320.50 of \$2,000.00 spent'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('2 of 3 sharing'), findsOneWidget);
  });

  testWidgets('over budget says so', (t) async {
    await _pump(t, members: _team, budgets: const [HouseholdBudget(category: null, amountCents: 100000)]);
    expect(find.text('\$320.50 over budget'), findsOneWidget);
  });

  testWidgets('someone who is not sharing is nudged to share theirs', (t) async {
    await _pump(t, members: [_m('me', sharing: false), _m('ann', owner: true, cats: {'Food': 1000})],
        budgets: const [HouseholdBudget(category: null, amountCents: 5000)]);
    expect(find.text('1 of 2 sharing · tap to share yours'), findsOneWidget);
  });

  testWidgets('someone who is sharing is not nudged', (t) async {
    await _pump(t, members: _team, budgets: const [HouseholdBudget(category: null, amountCents: 200000)]);
    expect(find.textContaining('tap to share yours'), findsNothing);
  });

  testWidgets('without a budget the admin is invited to set one', (t) async {
    await _pump(t, members: _team);
    expect(find.text('\$1,320.50'), findsOneWidget);
    expect(find.text('spent so far. Tap to set a budget.'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('without a budget an ordinary member just sees the spending', (t) async {
    await _pump(t, members: [_m('me', cats: {'Food': 5000}), _m('ann', owner: true, sharing: false)]);
    expect(find.text('spent so far this month'), findsOneWidget);
    expect(find.textContaining('set a budget'), findsNothing);
  });

  testWidgets('tapping the card opens the household budget', (t) async {
    var taps = 0;
    await _pump(t, members: _team, onTap: () => taps++);
    await t.tap(find.text('Household budget · Oct'));
    expect(taps, 1);
  });

  testWidgets('it keeps showing this month while the household screen looks at an earlier one', (t) async {
    final p = await _pump(t, members: _team, budgets: const [HouseholdBudget(category: null, amountCents: 200000)]);
    await t.runAsync(p.previousMonth);
    await t.pumpAndSettle();
    expect(p.month, DateTime(2026, 9));
    expect(find.text('Household budget · Oct'), findsOneWidget);
  });

  testWidgets('it disappears when the person signs out', (t) async {
    final p = await _pump(t, members: _team, budgets: const [HouseholdBudget(category: null, amountCents: 200000)]);
    expect(find.text('Household budget · Oct'), findsOneWidget);
    p.clear();
    await t.pumpAndSettle();
    expect(find.textContaining('Household budget'), findsNothing);
  });
}
