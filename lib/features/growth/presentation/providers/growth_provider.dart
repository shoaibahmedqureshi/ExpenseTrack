import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionException, PostgrestException;
import '../../data/growth_repository.dart';
import '../../domain/growth_models.dart';

class GrowthProvider extends ChangeNotifier {
  GrowthProvider({required this.repository});
  final GrowthRepository repository;

  bool _adminChecked = false;
  bool _isAdmin = false;
  List<OutreachTask> _tasks = [];
  List<CreatorApplication> _apps = [];
  bool _loading = false;
  String? _error;
  bool _loadFailed = false;

  bool get isAdmin => _isAdmin;
  bool get adminChecked => _adminChecked;
  List<OutreachTask> get tasks => _tasks;
  List<CreatorApplication> get applications => _apps;
  bool get isLoading => _loading;
  String? get error => _error;

  /// True only when the last list load failed (an action failing does not count).
  bool get loadFailed => _loadFailed && _error != null;

  int get awaitingReview => _apps.where((a) => a.awaitingDecision).length;
  int todayCount(DateTime now) =>
      _tasks.where((t) => t.bucket(now) == TaskBucket.today).length;

  String _msg(Object e) {
    if (e is PostgrestException) return e.message;
    if (e is FunctionException) {
      final d = e.details;
      if (d is Map && d['error'] is String) return d['error'] as String;
      return 'The request failed (${e.status})';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  /// Asks the server whether this user is an admin (once per sign-in).
  Future<void> checkAdmin() async {
    if (_adminChecked) return;
    _isAdmin = await repository.isAdmin();
    _adminChecked = true;
    notifyListeners();
    if (_isAdmin) await load();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    _loadFailed = false;
    notifyListeners();
    try {
      final r =
          await Future.wait([repository.tasks(), repository.applications()]);
      _tasks = r[0] as List<OutreachTask>;
      _apps = r[1] as List<CreatorApplication>;
    } catch (e) {
      _error = _msg(e);
      _loadFailed = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> _do(Future<void> Function() action) async {
    try {
      await action();
      _error = null;
      await load();
      return true;
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> addTask({
    required String creatorName,
    required String platform,
    required OutreachChannel channel,
    String? handle,
    String? profileUrl,
    String? niche,
    String? fitReason,
    String? evidence,
    String? draftMessage,
    String? notes,
  }) =>
      _do(() => repository.addTask(
            creatorName: creatorName,
            platform: platform,
            channel: channel,
            handle: handle,
            profileUrl: profileUrl,
            niche: niche,
            fitReason: fitReason,
            evidence: evidence,
            draftMessage: draftMessage,
            notes: notes,
          ));

  Future<bool> markSent(OutreachTask t) =>
      _do(() => repository.updateTask(t.id, {
            'status': 'sent',
            'sent_at': DateTime.now().toUtc().toIso8601String(),
            'followup_at':
                DateTime.now().add(followUpAfter).toUtc().toIso8601String(),
          }));

  Future<bool> setStatus(OutreachTask t, TaskStatus s) =>
      _do(() => repository.updateTask(t.id, {'status': s.key}));

  Future<bool> snooze(OutreachTask t, Duration d) =>
      _do(() => repository.updateTask(t.id, {
            'status': 'snoozed',
            'due_at': DateTime.now().add(d).toUtc().toIso8601String(),
          }));

  Future<bool> saveNotes(OutreachTask t, String notes) => _do(() => repository
      .updateTask(t.id, {'notes': notes.trim().isEmpty ? null : notes.trim()}));

  Future<bool> deleteTask(OutreachTask t) =>
      _do(() => repository.deleteTask(t.id));

  Future<bool> approve(CreatorApplication a, String? notes) =>
      _do(() => repository.approveApplication(
            id: a.id,
            notes: notes,
            draftMessage: welcomeDraft(a.name),
            taskNotes:
                'Approved application. Create the store offers and the influencer_codes row first, '
                'put the code in the message, then email ${a.email}.',
          ));

  Future<bool> reject(CreatorApplication a, String? notes) =>
      _do(() => repository.decide(a.id, ApplicationStatus.rejected, notes));

  Future<DraftResult?> draft({
    required String creatorName,
    required String platform,
    required OutreachChannel channel,
    String? handle,
    String? profileUrl,
    String? creatorInfo,
  }) async {
    try {
      final r = await repository.draft(
        creatorName: creatorName,
        platform: platform,
        channel: channel,
        handle: handle,
        profileUrl: profileUrl,
        creatorInfo: creatorInfo,
      );
      _error = null;
      return r;
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
      return null;
    }
  }

  void clear() {
    _adminChecked = false;
    _isAdmin = false;
    _tasks = [];
    _apps = [];
    _error = null;
    _loadFailed = false;
    _loading = false;
    notifyListeners();
  }
}
