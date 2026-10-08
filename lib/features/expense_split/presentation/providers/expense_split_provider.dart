import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../../data/expense_split_repository.dart';
import '../../domain/split_calculator.dart';
import '../../domain/split_models.dart';

class ExpenseSplitProvider extends ChangeNotifier {
  ExpenseSplitProvider({required this.repository, required this.getCurrentUserId});

  final ExpenseSplitRepository repository;
  final String Function() getCurrentUserId;

  Ledger? _ledger;
  List<ExpenseSplit> _splits = [];
  List<SplitSettlement> _settlements = [];
  List<LedgerBalance> _overview = [];
  bool _loading = false;
  String? _error;

  Ledger? get ledger => _ledger;
  List<ExpenseSplit> get splits => _splits;
  List<SplitSettlement> get settlements => _settlements;
  bool get isLoading => _loading;

  /// Standing in every ledger, for the dashboard.
  List<LedgerBalance> get overview => _overview;
  ({int owe, int owed}) get overviewTotals => SplitCalculator.overviewTotals(_overview.map((b) => b.netCents));
  bool get hasOverviewActivity => _overview.any((b) => b.hasActivity);

  Future<void> loadOverview() async {
    try {
      _overview = await repository.overview();
    } catch (_) {
      // The dashboard card simply stays as it was; the Splits tab reports its own errors.
    }
    notifyListeners();
  }
  String? get error => _error;

  Map<String, int> get net => SplitCalculator.netBalances(
        _splits.map((s) => (
              paidBy: s.paidBy,
              shares: {for (final sh in s.shares) sh.userId: sh.cents},
            )),
        _settlements.map((p) => (from: p.fromUser, to: p.toUser, cents: p.cents)),
      );

  List<Debt> get debts => SplitCalculator.simplifyDebts(net);
  int get myNet => net[getCurrentUserId()] ?? 0;

  String _msg(Object e) =>
      e is PostgrestException ? e.message : e.toString().replaceFirst('Exception: ', '');

  Future<void> load(Ledger ledger, {bool silent = false}) async {
    if (_ledger != ledger) {
      _splits = [];
      _settlements = [];
    }
    _ledger = ledger;
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final results = await Future.wait([
        repository.splits(ledger),
        repository.settlements(ledger),
      ]);
      _splits = results[0] as List<ExpenseSplit>;
      _settlements = results[1] as List<SplitSettlement>;
      _error = null;
    } catch (e) {
      _error = _msg(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Loads once per ledger; the Dashboard card and the Splits tab can both ask.
  Future<void> ensureLoaded(Ledger ledger) async {
    if (_ledger == ledger) return;
    await load(ledger);
  }

  Future<void> refresh() async {
    final l = _ledger;
    await Future.wait([loadOverview(), if (l != null) load(l, silent: true)]);
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    try {
      await action();
      _error = null;
      await refresh();
      return true;
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> createSplit({
    required String paidBy,
    required String description,
    required int totalCents,
    required SplitType type,
    required Map<String, int> sharesCents,
    Map<String, double>? percents,
  }) =>
      _mutate(() => repository.createSplit(
            ledger: _ledger!,
            paidBy: paidBy,
            description: description,
            totalCents: totalCents,
            type: type,
            sharesCents: sharesCents,
            percents: percents,
          ));

  Future<bool> settle({required String from, required String to, required int cents}) =>
      _mutate(() => repository.recordSettlement(
          ledger: _ledger!, from: from, to: to, cents: cents));

  Future<bool> deleteSplit(ExpenseSplit s) => _mutate(() => repository.deleteSplit(s.id));
  Future<bool> deleteSettlement(SplitSettlement s) =>
      _mutate(() => repository.deleteSettlement(s.id));

  void clear() {
    _ledger = null;
    _overview = [];
    _splits = [];
    _settlements = [];
    _loading = false;
    _error = null;
    notifyListeners();
  }
}
