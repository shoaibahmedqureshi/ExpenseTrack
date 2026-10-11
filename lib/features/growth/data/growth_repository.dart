import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/growth_models.dart';

class DraftResult {
  const DraftResult(
      {this.niche,
      this.fits,
      required this.fitReason,
      required this.evidence,
      required this.draft});
  final String? niche;
  final bool? fits;
  final String fitReason;
  final String evidence;
  final String draft;
}

class GrowthRepository {
  GrowthRepository(this._db);
  final SupabaseClient _db;

  Future<bool> isAdmin() async {
    try {
      final r = await _db.rpc('is_app_admin');
      return r == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<OutreachTask>> tasks() async {
    final rows =
        await _db.from('outreach_tasks').select().order('due_at').limit(500);
    return (rows as List)
        .map((r) => OutreachTask.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> addTask({
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
    String source = 'manual',
    int? applicationId,
  }) async {
    await _db.from('outreach_tasks').insert({
      'creator_name': creatorName,
      'platform': platform,
      'channel': channel.key,
      'handle': _blank(handle),
      'profile_url': _blank(profileUrl),
      'niche': _blank(niche),
      'fit_reason': _blank(fitReason),
      'evidence': _blank(evidence),
      'draft_message': _blank(draftMessage),
      'notes': _blank(notes),
      'source': source,
      'application_id': applicationId,
      'created_by': _db.auth.currentUser?.id,
    });
  }

  Future<void> updateTask(int id, Map<String, dynamic> fields) async {
    final done = await _db
        .from('outreach_tasks')
        .update(fields)
        .eq('id', id)
        .select('id');
    if ((done as List).isEmpty) throw Exception('Could not update this task');
  }

  Future<void> deleteTask(int id) async {
    final done =
        await _db.from('outreach_tasks').delete().eq('id', id).select('id');
    if ((done as List).isEmpty) throw Exception('Could not delete this task');
  }

  Future<List<CreatorApplication>> applications() async {
    final rows = await _db
        .from('creator_applications')
        .select()
        .order('created_at', ascending: false)
        .limit(300);
    return (rows as List)
        .map((r) =>
            CreatorApplication.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> decide(int id, ApplicationStatus status, String? notes) async {
    final done = await _db
        .from('creator_applications')
        .update({
          'status': status.key,
          'admin_notes': _blank(notes),
          'decided_by': _db.auth.currentUser?.id,
          'decided_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select('id');
    if ((done as List).isEmpty) throw Exception('Could not save the decision');
  }

  /// Approves a confirmed application and queues its follow-up task in one database
  /// transaction, so a failure can never leave it approved with nothing to do.
  Future<void> approveApplication({
    required int id,
    String? notes,
    required String draftMessage,
    required String taskNotes,
  }) async {
    await _db.rpc('admin_approve_application', params: {
      'p_id': id,
      'p_notes': notes ?? '',
      'p_draft': draftMessage,
      'p_task_notes': taskNotes,
    });
  }

  Future<DraftResult> draft({
    required String creatorName,
    required String platform,
    required OutreachChannel channel,
    String? handle,
    String? profileUrl,
    String? creatorInfo,
  }) async {
    final res = await _db.functions.invoke('outreach_draft', body: {
      'creator_name': creatorName,
      'platform': platform,
      'channel': channel.key,
      'handle': handle ?? '',
      'profile_url': profileUrl ?? '',
      'creator_info': creatorInfo ?? '',
    });
    final d = Map<String, dynamic>.from(res.data as Map);
    return DraftResult(
      niche: d['niche'] as String?,
      fits: d['fits'] as bool?,
      fitReason: (d['fit_reason'] as String?) ?? '',
      evidence: (d['evidence'] as String?) ?? '',
      draft: (d['draft'] as String?) ?? '',
    );
  }

  String? _blank(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();
}
