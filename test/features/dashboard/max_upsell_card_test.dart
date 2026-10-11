import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/dashboard/presentation/widgets/max_upsell_card.dart';
import 'package:outlay/features/family_accounts/domain/entities/family_group.dart';
import 'package:outlay/features/family_accounts/domain/repositories/family_repository.dart';
import 'package:outlay/features/family_accounts/presentation/providers/family_provider.dart';
import 'package:outlay/features/subscription/data/subscription_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Family implements FamilyRepository {
  _Family(this.families);
  final List<FamilyGroup> families;
  @override
  Future<List<FamilyGroup>> getUserFamilyGroups(String userId) async =>
      families;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

FamilyGroup _group() => FamilyGroup(
    id: '1',
    creatorId: 'x',
    name: 'Home',
    memberCount: 2,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026));

final _now = DateTime(2026, 10, 12, 12);

Future<int> _pump(
  WidgetTester t, {
  String plan = 'free',
  bool family = false,
  Map<String, Object> prefs = const {},
  DateTime Function()? now,
}) async {
  SharedPreferences.setMockInitialValues({'sub_plan': plan, ...prefs});
  final p = await SharedPreferences.getInstance();
  final fam = FamilyProvider(
      repository: _Family(family ? [_group()] : []),
      getCurrentUserId: () => 'me');
  await fam.loadUserFamilies();
  var upgrades = 0;
  await t.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<SubscriptionService>(
          create: (_) => SubscriptionService(p, debugProducts: const [])),
      ChangeNotifierProvider<FamilyProvider>.value(value: fam),
    ],
    child: MaterialApp(
        home: Scaffold(
            body: MaxUpsellCard(
                onUpgrade: () => upgrades++, now: now ?? () => _now))),
  ));
  await t.pumpAndSettle();
  return upgrades;
}

void main() {
  group('shouldShowMaxCard', () {
    test('shows to someone with neither MAX nor a family', () {
      expect(
          shouldShowMaxCard(
              isMax: false, hasFamily: false, dismissedAt: null, now: _now),
          isTrue);
    });
    test('never shows to MAX or to a family member', () {
      expect(
          shouldShowMaxCard(
              isMax: true, hasFamily: false, dismissedAt: null, now: _now),
          isFalse);
      expect(
          shouldShowMaxCard(
              isMax: false, hasFamily: true, dismissedAt: null, now: _now),
          isFalse);
    });
    test('stays hidden for 30 days after a dismissal, then returns', () {
      final d = DateTime(2026, 9, 20);
      expect(
          shouldShowMaxCard(
              isMax: false,
              hasFamily: false,
              dismissedAt: d,
              now: d.add(const Duration(days: 29))),
          isFalse);
      expect(
          shouldShowMaxCard(
              isMax: false,
              hasFamily: false,
              dismissedAt: d,
              now: d.add(const Duration(days: 30))),
          isTrue);
    });
  });

  group('MaxUpsellCard', () {
    testWidgets('is shown to a Free user', (t) async {
      await _pump(t);
      expect(find.text('Budget together with MAX'), findsOneWidget);
    });

    testWidgets('is shown to a Pro user', (t) async {
      await _pump(t, plan: 'pro');
      expect(find.text('Budget together with MAX'), findsOneWidget);
    });

    testWidgets('is hidden for a family member on a lower plan', (t) async {
      await _pump(t, family: true);
      expect(find.text('Budget together with MAX'), findsNothing);
    });

    testWidgets('is hidden from a remembered family member before their family has loaded', (t) async {
      SharedPreferences.setMockInitialValues({'family_hint_me': true});
      final p = await SharedPreferences.getInstance();
      final fam = FamilyProvider(repository: _Family([]), getCurrentUserId: () => 'me', prefs: p); // not loaded
      await t.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<SubscriptionService>(create: (_) => SubscriptionService(p, debugProducts: const [])),
          ChangeNotifierProvider<FamilyProvider>.value(value: fam),
        ],
        child: MaterialApp(home: Scaffold(body: MaxUpsellCard(onUpgrade: () {}, now: () => _now))),
      ));
      await t.pumpAndSettle();
      expect(find.text('Budget together with MAX'), findsNothing);
    });

    testWidgets('tapping it opens the upgrade', (t) async {
      var upgrades = 0;
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      await t.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<SubscriptionService>(
              create: (_) => SubscriptionService(p, debugProducts: const [])),
          ChangeNotifierProvider<FamilyProvider>(
              create: (_) => FamilyProvider(
                  repository: _Family([]), getCurrentUserId: () => 'me')),
        ],
        child: MaterialApp(
            home: Scaffold(body: MaxUpsellCard(onUpgrade: () => upgrades++))),
      ));
      await t.pumpAndSettle();
      await t.tap(find.text('Budget together with MAX'));
      expect(upgrades, 1);
    });

    testWidgets('dismissing hides it and remembers for next time', (t) async {
      await _pump(t);
      await t.tap(find.byTooltip('Not now'));
      await t.pumpAndSettle();
      expect(find.text('Budget together with MAX'), findsNothing);
      final saved = (await SharedPreferences.getInstance())
          .getInt('max_card_dismissed_at');
      expect(saved, _now.millisecondsSinceEpoch);
    });

    testWidgets('stays hidden when it was dismissed recently', (t) async {
      await _pump(t, prefs: {
        'max_card_dismissed_at':
            _now.subtract(const Duration(days: 3)).millisecondsSinceEpoch
      });
      expect(find.text('Budget together with MAX'), findsNothing);
    });

    testWidgets('comes back after the snooze ends', (t) async {
      await _pump(t, prefs: {
        'max_card_dismissed_at':
            _now.subtract(const Duration(days: 31)).millisecondsSinceEpoch
      });
      expect(find.text('Budget together with MAX'), findsOneWidget);
    });
  });
}
