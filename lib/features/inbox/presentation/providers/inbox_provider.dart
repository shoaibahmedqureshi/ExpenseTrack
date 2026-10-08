import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../../data/inbox_repository.dart';
import '../../domain/inbox_item.dart';

class InboxProvider extends ChangeNotifier {
  InboxProvider({
    required this.repository,
    required this.getCurrentUserId,
    this.onSplitActivity,
  });

  final InboxRepository repository;
  final String Function() getCurrentUserId;

  /// Called when a new split or payment notification arrives, so balances can refresh.
  final VoidCallback? onSplitActivity;
  Set<int>? _knownIds;

  List<InboxItem> _items = [];
  bool _loading = false;
  String? _error;
  RealtimeChannel? _channel;
  String? _subscribedFor;

  List<InboxItem> get items => _items;
  bool get isLoading => _loading;
  String? get error => _error;
  int get unreadCount => _items.where((i) => !i.isRead).length;

  /// Loads the inbox and starts listening for new notifications (idempotent per user).
  Future<void> start() async {
    final uid = getCurrentUserId();
    if (uid.isEmpty || _subscribedFor == uid) return;
    await _unsubscribe();
    _subscribedFor = uid;
    _channel = repository.subscribe(uid, () => load(silent: true));
    await load();
  }

  Future<void> stop() async {
    await _unsubscribe();
    _subscribedFor = null;
    _knownIds = null;
    _items = [];
    _error = null;
    _loading = false;
    notifyListeners();
  }

  Future<void> _unsubscribe() async {
    final c = _channel;
    _channel = null;
    if (c != null) {
      try {
        await repository.unsubscribe(c);
      } catch (_) {}
    }
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      notifyListeners();
    }
    try {
      final fresh = await repository.list();
      final known = _knownIds;
      if (known != null &&
          fresh.any((i) => !known.contains(i.id) && (i.type == 'split_added' || i.type == 'payment_recorded' || i.type == 'group_invite' || i.type == 'group_member_joined'))) {
        onSplitActivity?.call();
      }
      _knownIds = fresh.map((i) => i.id).toSet();
      _items = fresh;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(InboxItem item) async {
    if (item.isRead) return;
    _items = [for (final i in _items) i.id == item.id ? i.markedRead() : i];
    notifyListeners();
    try {
      await repository.markRead(item.id);
    } catch (_) {
      await load(silent: true);
    }
  }

  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    _items = [for (final i in _items) i.markedRead()];
    notifyListeners();
    try {
      await repository.markAllRead(getCurrentUserId());
    } catch (_) {
      await load(silent: true);
    }
  }

  Future<void> delete(InboxItem item) async {
    _items = _items.where((i) => i.id != item.id).toList();
    notifyListeners();
    try {
      await repository.delete(item.id);
    } catch (_) {
      await load(silent: true);
    }
  }
}
