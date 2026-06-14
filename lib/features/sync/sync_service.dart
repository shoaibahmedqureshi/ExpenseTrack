import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';

/// Pushes locally-created records to Supabase and pulls remote
/// records that don't exist locally yet.
///
/// Call [run] on app start and whenever connectivity is restored.
class SyncService {
  SyncService(this._db, this._client);

  final Database _db;
  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  Future<void> run() async {
    if (_uid == null) return;
    try {
      await _pushPendingCategories();
      await _pushPendingExpenses();
      await _pullRemoteCategories();
      await _pullRemoteExpenses();
    } catch (_) {
      // Sync is best-effort; failures are silent and retried next time.
    }
  }

  // ── Push ────────────────────────────────────────────────────

  Future<void> _pushPendingCategories() async {
    final rows = await _db.query(
      AppConstants.categoriesTable,
      where: 'is_synced = 0',
    );
    for (final row in rows) {
      final remote = await _client.from('categories').upsert({
        'user_id': _uid,
        'name': row['name'],
        'icon_key': row['icon_key'],
        'color': row['color'],
      }).select().single();

      await _db.update(
        AppConstants.categoriesTable,
        {'remote_id': remote['id'].toString(), 'is_synced': 1},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<void> _pushPendingExpenses() async {
    final rows = await _db.query(
      AppConstants.expensesTable,
      where: 'is_synced = 0',
    );
    for (final row in rows) {
      // Resolve the remote category id from the local category's remote_id.
      final catRows = await _db.query(
        AppConstants.categoriesTable,
        where: 'id = ?',
        whereArgs: [row['category_id']],
      );
      final remCatId = catRows.isNotEmpty
          ? int.tryParse(catRows.first['remote_id']?.toString() ?? '')
          : null;

      final remote = await _client.from('expenses').upsert({
        'user_id': _uid,
        'local_id': row['id'],
        'title': row['title'],
        'amount': row['amount'],
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
  }

  // ── Pull ────────────────────────────────────────────────────

  Future<void> _pullRemoteCategories() async {
    final remote = await _client
        .from('categories')
        .select()
        .eq('user_id', _uid!);

    for (final row in remote) {
      final exists = await _db.query(
        AppConstants.categoriesTable,
        where: 'remote_id = ?',
        whereArgs: [row['id'].toString()],
      );
      if (exists.isEmpty) {
        await _db.insert(AppConstants.categoriesTable, {
          'name': row['name'],
          'icon_key': row['icon_key'],
          'color': row['color'],
          'remote_id': row['id'].toString(),
          'is_synced': 1,
        });
      }
    }
  }

  Future<void> _pullRemoteExpenses() async {
    final remote = await _client
        .from('expenses')
        .select()
        .eq('user_id', _uid!);

    for (final row in remote) {
      final exists = await _db.query(
        AppConstants.expensesTable,
        where: 'remote_id = ?',
        whereArgs: [row['id'].toString()],
      );
      if (exists.isEmpty) {
        // Find the local category id by matching remote category id.
        int? localCatId;
        if (row['category_id'] != null) {
          final cats = await _db.query(
            AppConstants.categoriesTable,
            where: 'remote_id = ?',
            whereArgs: [row['category_id'].toString()],
          );
          localCatId = cats.isNotEmpty ? cats.first['id'] as int? : null;
        }
        if (localCatId == null) continue;

        await _db.insert(AppConstants.expensesTable, {
          'title': row['title'],
          'amount': row['amount'],
          'date': row['date'],
          'type': row['type'],
          'category_id': localCatId,
          'note': row['note'],
          'remote_id': row['id'].toString(),
          'is_synced': 1,
        });
      }
    }
  }
}
