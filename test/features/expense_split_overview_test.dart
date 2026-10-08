import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/expense_split/data/expense_split_repository.dart';
import 'package:outlay/features/expense_split/domain/split_calculator.dart';
import 'package:outlay/features/expense_split/domain/split_models.dart';
import 'package:outlay/features/expense_split/presentation/providers/expense_split_provider.dart';

class _FakeRepo implements ExpenseSplitRepository {
  List<LedgerBalance> balances = [];
  Object? failWith;
  int overviewCalls = 0;

  @override
  Future<List<LedgerBalance>> overview() async {
    overviewCalls++;
    if (failWith != null) throw failWith!;
    return balances;
  }

  @override
  Future<List<ExpenseSplit>> splits(Ledger ledger) async => const [];
  @override
  Future<List<SplitSettlement>> settlements(Ledger ledger) async => const [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

LedgerBalance _b(LedgerKind k, int id, String name, int net, {bool activity = true}) =>
    LedgerBalance(ledger: Ledger(k, id, name), netCents: net, hasActivity: activity);

void main() {
  group('overviewTotals', () {
    test('adds up what you owe and what you are owed, without netting groups against each other', () {
      final t = SplitCalculator.overviewTotals([3000, -3000, -500, 1250]);
      expect(t.owe, 3500);
      expect(t.owed, 4250);
    });
    test('settled and empty both total zero', () {
      expect(SplitCalculator.overviewTotals([0, 0]), (owe: 0, owed: 0));
      expect(SplitCalculator.overviewTotals(const []), (owe: 0, owed: 0));
    });
  });

  group('LedgerBalance.fromJson', () {
    test('parses a group row', () {
      final b = LedgerBalance.fromJson({'kind': 'group', 'id': 3, 'name': 'Trip', 'net': -30.5, 'has_activity': true});
      expect(b.ledger, const Ledger(LedgerKind.group, 3, 'Trip'));
      expect(b.netCents, -3050);
      expect(b.hasActivity, isTrue);
    });
    test('parses a family row', () {
      final b = LedgerBalance.fromJson({'kind': 'family', 'id': 1, 'name': 'Home', 'net': 0, 'has_activity': false});
      expect(b.ledger.kind, LedgerKind.family);
      expect(b.netCents, 0);
      expect(b.hasActivity, isFalse);
    });
  });

  group('ExpenseSplitProvider overview', () {
    ExpenseSplitProvider make(_FakeRepo r) => ExpenseSplitProvider(repository: r, getCurrentUserId: () => 'me');

    test('loads the standing in every ledger and totals it', () async {
      final repo = _FakeRepo()
        ..balances = [_b(LedgerKind.group, 1, 'Trip', -3000), _b(LedgerKind.group, 2, 'Flat', 3000), _b(LedgerKind.family, 9, 'Home', 0)];
      final p = make(repo);
      await p.loadOverview();
      expect(p.overview.length, 3);
      expect(p.overviewTotals, (owe: 3000, owed: 3000));
      expect(p.hasOverviewActivity, isTrue);
    });

    test('no activity anywhere hides the card', () async {
      final repo = _FakeRepo()..balances = [_b(LedgerKind.group, 1, 'Trip', 0, activity: false)];
      final p = make(repo);
      await p.loadOverview();
      expect(p.hasOverviewActivity, isFalse);
    });

    test('a failed load keeps the previous figures', () async {
      final repo = _FakeRepo()..balances = [_b(LedgerKind.group, 1, 'Trip', 500)];
      final p = make(repo);
      await p.loadOverview();
      repo.failWith = Exception('offline');
      await p.loadOverview();
      expect(p.overview.single.netCents, 500);
    });

    test('refresh reloads the overview even before any ledger is open', () async {
      final repo = _FakeRepo();
      final p = make(repo);
      await p.refresh();
      expect(repo.overviewCalls, 1);
    });

    test('clear (sign-out) drops the overview', () async {
      final repo = _FakeRepo()..balances = [_b(LedgerKind.group, 1, 'Trip', 500)];
      final p = make(repo);
      await p.loadOverview();
      p.clear();
      expect(p.overview, isEmpty);
    });
  });
}
