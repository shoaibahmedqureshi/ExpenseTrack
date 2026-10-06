import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/inbox_item.dart';

class InboxRepository {
  InboxRepository(this._db);
  final SupabaseClient _db;

  Future<List<InboxItem>> list({int limit = 100}) async {
    final rows = await _db
        .from('inbox_notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => InboxItem.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> markRead(int id) => _db
      .from('inbox_notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id)
      .isFilter('read_at', null);

  Future<void> markAllRead(String userId) => _db
      .from('inbox_notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('user_id', userId)
      .isFilter('read_at', null);

  Future<void> delete(int id) => _db.from('inbox_notifications').delete().eq('id', id);

  /// Calls [onNew] whenever a notification row is created for [userId].
  RealtimeChannel subscribe(String userId, void Function() onNew) {
    return _db
        .channel('inbox:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'inbox_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onNew(),
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel channel) => _db.removeChannel(channel);
}
