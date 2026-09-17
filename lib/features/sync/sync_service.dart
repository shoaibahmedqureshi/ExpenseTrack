import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/device_debug_id.dart';
import 'category_reconciliation.dart';

/// Pushes locally-created records to Supabase and pulls remote
/// records that don't exist locally yet.
///
/// Call [run] on app start and whenever connectivity is restored.
///
/// Category reconciliation (matching each device's independently-seeded
/// defaults, and merging any that end up duplicated) is pure decision
/// logic lifted into category_reconciliation.dart and unit-tested there —
/// this class only performs the DB/network I/O the plans call for.
class SyncService {
  // uidOverride exists purely for tests exercising dedupeLocalCategories/
  // dedupeLocalBudgets against a real in-memory database (see
  // sync_service_dedupe_test.dart) — there's no way to get a real signed-in
  // uid out of SupabaseClient without a live network session, and these
  // methods now need one to scope their queries per user like everything
  // else in this class. Production call sites never pass it; _uid falls
  // back to the real authenticated user.
  SyncService(this._db, this._client, {String? uidOverride})
      : _uidOverride = uidOverride;

  static const _timeout = Duration(seconds: 20);

  final Database _db;
  final SupabaseClient _client;
  final String? _uidOverride;

  String? get _uid => _uidOverride ?? _client.auth.currentUser?.id;

  static const _maxAttempts = 3;
  static const _retryDelay = Duration(seconds: 3);

  // main.dart fires SyncService(...).run() independently from auth-changed,
  // connectivity-restored, and a 30s periodic timer — each creates its own
  // SyncService instance, so this guard has to be static rather than an
  // instance field. Without it, two overlapping runs both read the same
  // is_synced = 0 categories before either has updated is_synced, and both
  // push them as separate new remote rows — a real duplicate source on a
  // single device, not just across two devices.
  static bool _isRunning = false;

  // Observable counterpart to _isRunning: ExpenseProvider's first load is
  // now a purely local query (decoupled from sync to fix the "budget
  // shows 0 spent" bug, which needed local-only reconciliation to run
  // before Dashboard ever sees data) — meaning it's fast enough that a
  // loader gated on it alone is imperceptible, not meaningfully covering
  // the window where sync might still be pulling in data the local DB
  // doesn't have yet. Dashboard listens to this directly so its loader
  // spans the real "data might still be incomplete" window, not just the
  // now-trivial local-load window.
  static final ValueNotifier<bool> isSyncingNotifier = ValueNotifier(false);

  Future<void> run() async {
    if (_uid == null) return;
    if (_isRunning) return;
    _isRunning = true;
    isSyncingNotifier.value = true;
    try {
      for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
        var categoriesPushed = 0, expensesPushed = 0, budgetsPushed = 0;
        var categoriesPulled = 0, expensesPulled = 0, budgetsPulled = 0;
        try {
          await Future(() async {
            categoriesPushed = await _pushPendingCategories();
            expensesPushed = await _pushPendingExpenses();
            budgetsPushed = await _pushPendingBudgets();
            categoriesPulled = await _pullRemoteCategories();
            expensesPulled = await _pullRemoteExpenses();
            budgetsPulled = await _pullRemoteBudgets();
            await dedupeLocalCategories();
            await dedupeLocalBudgets();
          }).timeout(_timeout);
          await _uploadDebugSnapshot(
            attempt: attempt,
            succeeded: true,
            error: null,
            categoriesPushed: categoriesPushed,
            expensesPushed: expensesPushed,
            budgetsPushed: budgetsPushed,
            categoriesPulled: categoriesPulled,
            expensesPulled: expensesPulled,
            budgetsPulled: budgetsPulled,
          );
          return;
        } catch (e) {
          debugPrint('[SyncService] attempt $attempt/$_maxAttempts failed/timed out: $e');
          await _uploadDebugSnapshot(
            attempt: attempt,
            succeeded: false,
            error: e.toString(),
            categoriesPushed: categoriesPushed,
            expensesPushed: expensesPushed,
            budgetsPushed: budgetsPushed,
            categoriesPulled: categoriesPulled,
            expensesPulled: expensesPulled,
            budgetsPulled: budgetsPulled,
          );
          if (attempt < _maxAttempts) await Future.delayed(_retryDelay);
        }
      }
    } finally {
      _isRunning = false;
      isSyncingNotifier.value = false;
    }
  }

  /// Temporary: one row per sync attempt, on every device, so a stalled or
  /// silently-failing sync is directly visible instead of guessed at. See
  /// supabase/schema.sql's sync_debug_logs. Safe to remove once the
  /// cross-device budget sync bug is confirmed fixed.
  Future<void> _uploadDebugSnapshot({
    required int attempt,
    required bool succeeded,
    required String? error,
    required int categoriesPushed,
    required int expensesPushed,
    required int budgetsPushed,
    required int categoriesPulled,
    required int expensesPulled,
    required int budgetsPulled,
  }) async {
    if (!kDebugMode) return;
    if (_uid == null) return;
    try {
      final budgetsLocalTotal = Sqflite.firstIntValue(
        await _db.rawQuery(
          'SELECT COUNT(*) FROM ${AppConstants.budgetsTable} WHERE user_id = ?',
          [_uid],
        ),
      );
      final deviceId = await DeviceDebugId.get();
      await _client.from('sync_debug_logs').insert({
        'user_id': _uid,
        'device_id': deviceId,
        'attempt': attempt,
        'succeeded': succeeded,
        'error': error,
        'categories_pushed': categoriesPushed,
        'expenses_pushed': expensesPushed,
        'budgets_pushed': budgetsPushed,
        'categories_pulled': categoriesPulled,
        'expenses_pulled': expensesPulled,
        'budgets_pulled': budgetsPulled,
        'budgets_local_total': budgetsLocalTotal,
      });
    } catch (e) {
      debugPrint('[SyncService] debug snapshot upload failed: $e');
    }
  }

  // ── Push ────────────────────────────────────────────────────

  Future<int> _pushPendingCategories() async {
    final rows = await _db.query(
      AppConstants.categoriesTable,
      where: 'is_synced = 0 AND user_id = ?',
      whereArgs: [_uid],
    );
    for (final row in rows) {
      final name = row['name'] as String;
      final remoteCategories = await _client
          .from('categories')
          .select()
          .eq('user_id', _uid!);

      final plan = planCategoryPush(
        localName: name,
        remoteCategories: remoteCategories,
      );

      final Map<String, dynamic> remote;
      if (!plan.shouldCreateNew) {
        remote = remoteCategories.firstWhere(
          (r) => r['id'].toString() == plan.existingRemoteId,
        );
      } else {
        remote = await _client.from('categories').upsert({
          'user_id': _uid,
          'name': row['name'],
          'icon_key': row['icon_key'],
          'color': row['color'],
        }).select().single();
      }

      await _db.update(
        AppConstants.categoriesTable,
        {'remote_id': remote['id'].toString(), 'is_synced': 1},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    return rows.length;
  }

  Future<int> _pushPendingExpenses() async {
    final rows = await _db.query(
      AppConstants.expensesTable,
      where: 'is_synced = 0 AND user_id = ?',
      whereArgs: [_uid],
    );
    for (final row in rows) {
      // Resolve the remote category id from the local category's remote_id.
      final catRows = await _db.query(
        AppConstants.categoriesTable,
        where: 'id = ? AND user_id = ?',
        whereArgs: [row['category_id'], _uid],
      );
      final remCatId = catRows.isNotEmpty
          ? int.tryParse(catRows.first['remote_id']?.toString() ?? '')
          : null;

      final remote = await _client.from('expenses').upsert({
        'user_id': _uid,
        'local_id': row['id'],
        'title': row['title'],
        'amount': row['amount'],
        'tax': row['tax'],
        'date': row['date'],
        'type': row['type'],
        'category_id': remCatId,
        'note': row['note'],
      }).select().single();

      await _db.update(
        AppConstants.expensesTable,
        {'remote_id': remote['id'].toString(), 'is_synced': 1},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    return rows.length;
  }

  Future<int> _pushPendingBudgets() async {
    // Deletions first: a row can be both pending_delete and is_synced = 0
    // (e.g. deleted before it ever finished its first sync), so pushing
    // deletes before the upsert pass below means such a row is just
    // dropped rather than resurrected on Supabase for one round trip.
    await _pushPendingBudgetDeletes();

    final rows = await _db.query(
      AppConstants.budgetsTable,
      where: 'is_synced = 0 AND pending_delete = 0 AND user_id = ?',
      whereArgs: [_uid],
    );
    for (final row in rows) {
      int? remCatId;
      if (row['category_id'] != null) {
        final catRows = await _db.query(
          AppConstants.categoriesTable,
          where: 'id = ? AND user_id = ?',
          whereArgs: [row['category_id'], _uid],
        );
        remCatId = catRows.isNotEmpty
            ? int.tryParse(catRows.first['remote_id']?.toString() ?? '')
            : null;
      }

      final remote = await _client.from('budgets').upsert({
        'user_id': _uid,
        'local_id': row['id'],
        'category_id': remCatId,
        'month': row['month'],
        'amount': row['amount'],
      }).select().single();

      await _db.update(
        AppConstants.budgetsTable,
        {'remote_id': remote['id'].toString(), 'is_synced': 1},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    return rows.length;
  }

  /// Propagates local soft-deletes (see BudgetLocalDatasource.delete) to
  /// Supabase, then hard-deletes the local tombstone — the row is only
  /// truly gone once the remote side has been told, so a delete that ran
  /// while offline still reaches other devices the next time sync
  /// succeeds instead of staying a local-only removal forever.
  Future<void> _pushPendingBudgetDeletes() async {
    final rows = await _db.query(
      AppConstants.budgetsTable,
      where: 'pending_delete = 1 AND user_id = ?',
      whereArgs: [_uid],
    );
    for (final row in rows) {
      final remoteId = row['remote_id'] as String?;
      if (remoteId != null) {
        await _client.from('budgets').delete().eq('id', remoteId);
      }
      await _db.delete(
        AppConstants.budgetsTable,
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  // ── Pull ────────────────────────────────────────────────────

  Future<int> _pullRemoteCategories() async {
    final remote = await _client
        .from('categories')
        .select()
        .eq('user_id', _uid!);

    var changed = 0;
    for (final row in remote) {
      // Local rows are re-queried each iteration since the previous
      // iteration may have just inserted/linked one, and the plan for
      // *this* row needs to see that. Scoped to this user only — without
      // this, a remote category could get matched/linked against another
      // account's same-named local row instead of this account's own.
      final localCategories = await _db.query(
        AppConstants.categoriesTable,
        where: 'user_id = ?',
        whereArgs: [_uid],
      );
      final action = planPullCategory(
        remoteRow: row,
        localCategories: localCategories,
      );

      switch (action.type) {
        case PullCategoryActionType.alreadyLinked:
          break;
        case PullCategoryActionType.linkExistingLocal:
          await _db.update(
            AppConstants.categoriesTable,
            {'remote_id': row['id'].toString(), 'is_synced': 1},
            where: 'id = ? AND user_id = ?',
            whereArgs: [action.localIdToLink, _uid],
          );
          changed++;
        case PullCategoryActionType.insertNew:
          await _db.insert(AppConstants.categoriesTable, {
            'name': row['name'],
            'icon_key': row['icon_key'],
            'color': row['color'],
            'remote_id': row['id'].toString(),
            'is_synced': 1,
            'user_id': _uid,
          });
          changed++;
      }
    }
    return changed;
  }

  /// Merges any categories that ended up duplicated locally (matched by
  /// normalized name) before repointing every expense/budget that
  /// referenced a duplicate's id onto the surviving row, then deleting the
  /// duplicates. Safe to run on every sync — a no-op once nothing is
  /// duplicated, and it never deletes a row without first re-homing
  /// anything that pointed at it. Must run *after* the expense/budget
  /// pulls below, since those resolve categories by remote_id and rely on
  /// the (possibly temporarily duplicated) rows this pass cleans up still
  /// existing at pull time.
  ///
  /// Public (not `_`-prefixed) for two real callers, not just tests:
  /// main.dart runs this on every app start independent of network sync —
  /// local duplicates can exist before any sync ever succeeds (no
  /// connectivity yet on first launch), and a budget created against one
  /// duplicate while expenses got tagged against another (both looked
  /// identical in a picker, e.g. two "Food" rows) shows 0 spent forever
  /// otherwise, since BudgetProvider looks up spend by exact category id.
  /// Also exercised directly in tests against a real in-memory database —
  /// see test/features/sync/sync_service_dedupe_test.dart.
  Future<void> dedupeLocalCategories() async {
    final uid = _uid;
    if (uid == null) return;
    // Scoped to this user only — otherwise two different accounts that
    // both happen to have a "Food" category on the same device would get
    // merged into one shared row, repointing one account's expenses onto
    // a category that's really the other account's.
    final all = await _db.query(
      AppConstants.categoriesTable,
      where: 'user_id = ?',
      whereArgs: [uid],
    );
    final groups = planCategoryDedupe(all);

    for (final group in groups) {
      for (final dupId in group.duplicateIds) {
        await _db.update(
          AppConstants.expensesTable,
          {'category_id': group.keeperId},
          where: 'category_id = ? AND user_id = ?',
          whereArgs: [dupId, uid],
        );
        await _db.update(
          AppConstants.budgetsTable,
          {'category_id': group.keeperId},
          where: 'category_id = ? AND user_id = ?',
          whereArgs: [dupId, uid],
        );
        await _db.delete(
          AppConstants.categoriesTable,
          where: 'id = ? AND user_id = ?',
          whereArgs: [dupId, uid],
        );
      }
    }
  }

  /// Merges budgets that ended up duplicated for the same category (or
  /// Overall) and month — keeping one and tombstoning the rest so the
  /// removal is pushed to Supabase and reconciled on other devices on the
  /// next sync, rather than a hard local delete that would just reappear
  /// on the next pull. Two distinct ways this happens in practice: (1) the
  /// same class of bug dedupeLocalCategories fixes for categories — two
  /// devices independently creating a budget for the same month before
  /// either had synced — and (2) dedupeLocalCategories itself, immediately
  /// above, repointing two different budgets' category_id onto the same
  /// surviving category when it merges the duplicate categories they were
  /// each attached to. Must run after dedupeLocalCategories for exactly
  /// that second reason.
  ///
  /// Public for the same reason dedupeLocalCategories is: main.dart runs
  /// it on startup too, so stale duplicates disappear from the Budgets
  /// screen immediately rather than waiting on the next network sync.
  Future<void> dedupeLocalBudgets() async {
    final uid = _uid;
    if (uid == null) return;
    // Scoped to this user only — same reasoning as dedupeLocalCategories.
    final all = await _db.query(
      AppConstants.budgetsTable,
      where: 'pending_delete = 0 AND user_id = ?',
      whereArgs: [uid],
    );

    final groups = <String, List<Map<String, Object?>>>{};
    for (final row in all) {
      final catKey = row['category_id']?.toString() ?? 'overall';
      final month = DateTime.parse(row['month'] as String);
      final monthKey = DateTime(month.year, month.month, 1).toIso8601String();
      groups.putIfAbsent('$catKey|$monthKey', () => []).add(row);
    }

    for (final group in groups.values) {
      if (group.length <= 1) continue;
      // Keep the row other devices are already most likely to know about
      // (has a remote_id) so we tombstone the newer local duplicate rather
      // than the one that's already been seen elsewhere; otherwise keep
      // the oldest local row.
      group.sort((a, b) {
        final aSynced = a['remote_id'] != null ? 0 : 1;
        final bSynced = b['remote_id'] != null ? 0 : 1;
        if (aSynced != bSynced) return aSynced - bSynced;
        return (a['id'] as int).compareTo(b['id'] as int);
      });
      for (final dup in group.skip(1)) {
        await _db.update(
          AppConstants.budgetsTable,
          {'pending_delete': 1, 'is_synced': 0},
          where: 'id = ?',
          whereArgs: [dup['id']],
        );
      }
    }
  }

  Future<int> _pullRemoteExpenses() async {
    final remote = await _client
        .from('expenses')
        .select()
        .eq('user_id', _uid!);

    var inserted = 0;
    for (final row in remote) {
      final exists = await _db.query(
        AppConstants.expensesTable,
        where: 'remote_id = ? AND user_id = ?',
        whereArgs: [row['id'].toString(), _uid],
      );
      if (exists.isEmpty) {
        // Find the local category id by matching remote category id.
        int? localCatId;
        if (row['category_id'] != null) {
          final cats = await _db.query(
            AppConstants.categoriesTable,
            where: 'remote_id = ? AND user_id = ?',
            whereArgs: [row['category_id'].toString(), _uid],
          );
          localCatId = cats.isNotEmpty ? cats.first['id'] as int? : null;
        }
        if (localCatId == null) continue;

        await _db.insert(AppConstants.expensesTable, {
          'title': row['title'],
          'amount': row['amount'],
          'tax': row['tax'],
          'date': row['date'],
          'type': row['type'],
          'category_id': localCatId,
          'note': row['note'],
          'remote_id': row['id'].toString(),
          'is_synced': 1,
          'user_id': _uid,
        });
        inserted++;
      }
    }
    return inserted;
  }

  Future<int> _pullRemoteBudgets() async {
    final remote = await _client
        .from('budgets')
        .select()
        .eq('user_id', _uid!);

    // Reconcile deletions that happened on another device: a local row
    // that's already synced (has a remote_id) but whose id is no longer
    // in this result set was deleted remotely, so remove the now-orphaned
    // local copy too. This only ever runs after this device's own pending
    // pushes/deletes above have completed without throwing, so an empty
    // `remote` here reflects the real remote state, not a transient
    // failure that would otherwise wipe out every local budget.
    final remoteIds = remote.map((r) => r['id'].toString()).toSet();
    // Scoped to this user only — without this, a budget belonging to a
    // *different* account on this device (whose remote_id naturally isn't
    // in *this* account's remote result set either) would look identical
    // to a genuinely-deleted-elsewhere row and get wiped out here.
    final syncedLocal = await _db.query(
      AppConstants.budgetsTable,
      where: 'remote_id IS NOT NULL AND pending_delete = 0 AND user_id = ?',
      whereArgs: [_uid],
    );
    for (final row in syncedLocal) {
      if (!remoteIds.contains(row['remote_id'])) {
        await _db.delete(
          AppConstants.budgetsTable,
          where: 'id = ? AND user_id = ?',
          whereArgs: [row['id'], _uid],
        );
      }
    }

    var inserted = 0;
    for (final row in remote) {
      final exists = await _db.query(
        AppConstants.budgetsTable,
        where: 'remote_id = ? AND user_id = ?',
        whereArgs: [row['id'].toString(), _uid],
      );
      if (exists.isEmpty) {
        // Find the local category id by matching remote category id, if any.
        int? localCatId;
        if (row['category_id'] != null) {
          final cats = await _db.query(
            AppConstants.categoriesTable,
            where: 'remote_id = ? AND user_id = ?',
            whereArgs: [row['category_id'].toString(), _uid],
          );
          if (cats.isEmpty) continue;
          localCatId = cats.first['id'] as int?;
        }

        // The remote budgets.month column is a Postgres `date`, returned
        // here as a bare "2026-07-01" — a different string than the full
        // "2026-07-01T00:00:00.000" a locally-created budget stores.
        // Re-normalize through the same DateTime construction everywhere
        // else uses so every row in the local table has the identical
        // format regardless of whether it was created here or pulled in.
        // (BudgetLocalDatasource.getByMonth also compares via SQLite's
        // date() now, as a second layer of defense against this exact
        // mismatch — but storing consistently to begin with is cleaner.)
        final month = DateTime.parse(row['month'] as String);
        await _db.insert(AppConstants.budgetsTable, {
          'category_id': localCatId,
          'month': DateTime(month.year, month.month, 1).toIso8601String(),
          'amount': row['amount'],
          'remote_id': row['id'].toString(),
          'is_synced': 1,
          'user_id': _uid,
        });
        inserted++;
      }
    }
    return inserted;
  }
}
