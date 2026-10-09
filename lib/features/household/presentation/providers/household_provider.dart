import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException, RealtimeChannel;
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../../data/household_repository.dart';
import '../../domain/household_calculator.dart';
import '../../domain/household_models.dart';

/// The household budget view for the signed-in person's family, plus publishing their own monthly totals when
/// (and only when) they have chosen to share them.
class HouseholdProvider extends ChangeNotifier {
  HouseholdProvider({
    required this.repository,
    required this.getCurrentUserId,
    DateTime Function()? now,
    this.publishDelay = const Duration(seconds: 3),
    this.liveDelay = const Duration(seconds: 1),
  }) : _now = now ?? DateTime.now {
    final n = _now();
    _month = DateTime(n.year, n.month);
    _overview = HouseholdOverview.empty(_month);
    _current = _overview;
  }

  final HouseholdRepository repository;
  final String Function() getCurrentUserId;
  final DateTime Function() _now;
  final Duration publishDelay;

  /// How long to wait after a "something changed" message before reloading, so a burst becomes one reload.
  final Duration liveDelay;

  int? _familyId;
  late DateTime _month;
  late HouseholdOverview _overview;
  late HouseholdOverview _current;
  bool _loading = false;
  bool _loadedOnce = false;
  bool _busy = false;
  String? _error;
  ExpenseProvider? _expenses;
  Timer? _timer;
  Timer? _liveTimer;
  RealtimeChannel? _channel;
  int? _watchedFamily;

  int? get familyId => _familyId;
  DateTime get month => _month;
  HouseholdOverview get overview => _overview;

  /// How the household stands this month, whichever month the screen is looking at. The dashboard card uses this.
  HouseholdOverview get current => _current;
  DateTime get currentMonth => DateTime(_now().year, _now().month);
  bool get isLoading => _loading;
  bool get hasLoaded => _loadedOnce;
  bool get isBusy => _busy;
  String? get error => _error;

  HouseholdMember? get me => _overview.member(getCurrentUserId());
  bool get isSharing => me?.sharing ?? false;
  bool get isOwner => me?.isOwner ?? false;
  bool get canGoForward => _month.isBefore(DateTime(_now().year, _now().month));

  String _msg(Object e) => e is PostgrestException ? e.message : e.toString().replaceFirst('Exception: ', '');

  /// Loads the view for [familyId] and [month] (this month by default).
  Future<void> load(int familyId, {DateTime? month}) async {
    if (_familyId != familyId) {
      _overview = HouseholdOverview.empty(_month);
      _current = _overview;
      _loadedOnce = false;
    }
    _familyId = familyId;
    _watch(familyId);
    if (month != null) _month = DateTime(month.year, month.month);
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _overview = await repository.overview(familyId, _month);
      if (_month == currentMonth) _current = _overview;
      _loadedOnce = true;
    } catch (e) {
      _error = _msg(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> goToMonth(DateTime month) async {
    final id = _familyId;
    if (id == null) return;
    final target = DateTime(month.year, month.month);
    if (target.isAfter(DateTime(_now().year, _now().month))) return;
    await load(id, month: target);
  }

  Future<void> previousMonth() => goToMonth(DateTime(_month.year, _month.month - 1));
  Future<void> nextMonth() => goToMonth(DateTime(_month.year, _month.month + 1));

  /// Called when the app starts, after a sync, and when the family changes: learns whether this person is sharing and,
  /// if so, refreshes what they share. Does nothing for someone without a family.
  Future<void> syncFor(int? familyId) async {
    if (familyId == null) {
      clear();
      return;
    }
    await load(familyId, month: currentMonth);
    if (isSharing) await publishNow();
  }

  /// Hooks the provider to the expense list so changes are re-shared (after a short pause) while sharing is on.
  void attachExpenses(ExpenseProvider expenses) {
    _expenses?.removeListener(_onExpensesChanged);
    _expenses = expenses..addListener(_onExpensesChanged);
  }

  /// Listens for changes made by anyone in the family so the dashboard and household screen stay current without a refresh.
  void _watch(int familyId) {
    if (_watchedFamily == familyId) return;
    _stopWatching();
    _watchedFamily = familyId;
    try {
      _channel = repository.subscribe(familyId, _onLiveChange);
    } catch (e) {
      debugPrint('[HouseholdProvider] live updates unavailable: $e');
    }
  }

  void _stopWatching() {
    _liveTimer?.cancel();
    final c = _channel;
    _channel = null;
    _watchedFamily = null;
    if (c != null) {
      try {
        repository.unsubscribe(c);
      } catch (_) {}
    }
  }

  void _onLiveChange() {
    _liveTimer?.cancel();
    _liveTimer = Timer(liveDelay, _refreshQuietly);
  }

  /// Reloads this month (and the month on screen, if different) without showing a spinner.
  Future<void> _refreshQuietly() async {
    final id = _familyId;
    if (id == null || id != _watchedFamily) return;
    try {
      final cur = await repository.overview(id, currentMonth);
      if (_familyId != id) return; // signed out or changed family meanwhile
      _current = cur;
      _overview = _month == currentMonth ? cur : await repository.overview(id, _month);
      notifyListeners();
    } catch (_) {
      // Keep what is on screen; the next change or refresh will correct it.
    }
  }

  void _onExpensesChanged() {
    if (!isSharing || _familyId == null) return;
    _timer?.cancel();
    _timer = Timer(publishDelay, () {
      publishNow().then((_) {
        final id = _familyId;
        if (id != null) load(id);
      });
    });
  }

  /// Shares this month's and the last two months' category totals. Does nothing unless sharing is on.
  Future<void> publishNow() async {
    final id = _familyId;
    final expenses = _expenses;
    if (id == null || expenses == null || !isSharing) return;
    try {
      await repository.publish(id, SummaryBuilder.build(expenses.expenses, _now()));
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      final id = _familyId;
      if (id != null) {
        _overview = await repository.overview(id, _month);
        if (_month == currentMonth) _current = _overview;
      }
      return true;
    } catch (e) {
      _error = _msg(e);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Turns sharing on or off for the signed-in person. Turning it off deletes what they had shared.
  Future<bool> setSharing(bool enabled) {
    final id = _familyId;
    if (id == null) return Future.value(false);
    return _run(() async {
      await repository.setSharing(id, enabled);
      if (enabled) {
        // Sharing counts as on from here, so the publish below is accepted.
        final exp = _expenses;
        if (exp != null) await repository.publish(id, SummaryBuilder.build(exp.expenses, _now()));
      }
    });
  }

  /// Sets the overall budget ([category] null) or one category's, in cents. Admin only (the server enforces it).
  Future<bool> setBudget(String? category, int cents) {
    final id = _familyId;
    if (id == null) return Future.value(false);
    return _run(() => repository.setBudget(id, category, cents));
  }

  Future<bool> clearBudget(String? category) {
    final id = _familyId;
    if (id == null) return Future.value(false);
    return _run(() => repository.clearBudget(id, category));
  }

  void clear() {
    _timer?.cancel();
    _stopWatching();
    _familyId = null;
    final n = _now();
    _month = DateTime(n.year, n.month);
    _overview = HouseholdOverview.empty(_month);
    _current = _overview;
    _loading = false;
    _loadedOnce = false;
    _busy = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopWatching();
    _expenses?.removeListener(_onExpensesChanged);
    super.dispose();
  }
}
