import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/budget_model.dart';

class BudgetLocalDatasource {
  // uidOverride is a testing seam only — see ExpenseLocalDatasource.
  BudgetLocalDatasource(this._db, {String? uidOverride})
      : _uidOverride = uidOverride;

  final Database _db;
  final String? _uidOverride;

  // See ExpenseLocalDatasource._uid — same reasoning: read live, not
  // captured at construction, since this datasource outlives any one session.
  String? get _uid =>
      _uidOverride ?? Supabase.instance.client.auth.currentUser?.id;

  Future<List<BudgetModel>> getByMonth(DateTime month) async {
    final uid = _uid;
    if (uid == null) return [];
    final monthStart = DateTime(month.year, month.month, 1);
    // SQLite's date() normalizes both sides to a bare YYYY-MM-DD before
    // comparing. A plain string-equality WHERE month = ? looked fine in
    // testing but broke on real synced data: the remote budgets.month
    // column is a Postgres `date`, so a pulled row's month comes back as
    // "2026-07-01" while a locally-created row stores the full
    // "2026-07-01T00:00:00.000" — two different strings for the same
    // month, so the exact-match query silently found nothing for any
    // budget that arrived via sync, even though the row was really there.
    final rows = await _db.query(
      AppConstants.budgetsTable,
      where: 'date(month) = date(?) AND pending_delete = 0 AND user_id = ?',
      whereArgs: [monthStart.toIso8601String(), uid],
    );
    return rows.map(BudgetModel.fromMap).toList();
  }

  Future<int> insert(BudgetModel model) => _db.insert(
      AppConstants.budgetsTable, {...model.toMap(), 'user_id': _uid});

  Future<void> update(BudgetModel model) async {
    // is_synced must be reset explicitly: SQLite's UPDATE only touches the
    // columns present in the values map, unlike INSERT it does not fall
    // back to the column default for omitted ones. model.toMap() doesn't
    // include is_synced (it's a sync-layer concern, not a domain field),
    // so without this an already-synced budget's edited amount/category
    // would silently never get pushed — the row would keep looking synced
    // even though Supabase still has the pre-edit values.
    await _db.update(
      AppConstants.budgetsTable,
      {...model.toMap(), 'is_synced': 0},
      where: 'id = ? AND user_id = ?',
      whereArgs: [model.id, _uid],
    );
  }

  /// Soft-delete (tombstone): marks the row instead of removing it so
  /// SyncService can push the deletion to Supabase — and it can be
  /// reconciled away on other devices — before the row is actually gone.
  /// A hard local delete here would just get resurrected the next time
  /// this device pulled the still-present remote row.
  Future<void> delete(int id) async {
    await _db.update(
      AppConstants.budgetsTable,
      {'pending_delete': 1, 'is_synced': 0},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _uid],
    );
  }
}
