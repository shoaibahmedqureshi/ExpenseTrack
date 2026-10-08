import 'package:supabase_flutter/supabase_flutter.dart';
import '../../expense_split/domain/split_models.dart';
import '../domain/group_models.dart';

class SplitGroupRepository {
  SplitGroupRepository(this._db);
  final SupabaseClient _db;

  String? get _me => _db.auth.currentUser?.id;
  String get _email => (_db.auth.currentUser?.email ?? '').toLowerCase();

  Future<List<SplitGroup>> myGroups() async {
    final me = _me;
    if (me == null) return [];
    final rows = await _db
        .from('split_group_members')
        .select('role, joined_at, split_groups(id, name)')
        .eq('user_id', me)
        .order('joined_at');
    return (rows as List).map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final g = Map<String, dynamic>.from(m['split_groups'] as Map);
      return SplitGroup(id: g['id'] as int, name: g['name'] as String, isOwner: m['role'] == 'owner');
    }).toList();
  }

  Future<List<GroupInvitation>> myInvitations() async {
    if (_email.isEmpty) return [];
    final rows = await _db
        .from('split_group_invitations')
        .select('id, group_id, email, created_at, split_groups(name)')
        .eq('status', 'pending')
        .eq('email', _email)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return (rows as List).map((r) => GroupInvitation.fromJson(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<List<GroupInvitation>> sentInvitations(int groupId) async {
    final rows = await _db
        .from('split_group_invitations')
        .select('id, group_id, email, created_at, split_groups(name)')
        .eq('group_id', groupId)
        .eq('status', 'pending')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return (rows as List).map((r) => GroupInvitation.fromJson(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<List<LedgerMember>> members(int groupId) async {
    final res = await _db.rpc('list_group_members', params: {'p_group_id': groupId});
    return (res as List).map((m) => LedgerMember.fromJson(Map<String, dynamic>.from(m as Map))).toList();
  }

  Future<int> create(String name) async => (await _db.rpc('create_split_group', params: {'p_name': name})) as int;
  Future<void> rename(int groupId, String name) =>
      _db.rpc('rename_split_group', params: {'p_group_id': groupId, 'p_name': name});
  Future<void> invite(int groupId, String email) =>
      _db.rpc('invite_to_split_group', params: {'p_group_id': groupId, 'p_email': email});
  Future<void> respond(int invitationId, bool accept) =>
      _db.rpc('respond_to_group_invitation', params: {'p_invitation_id': invitationId, 'p_accept': accept});
  Future<void> cancelInvitation(int invitationId) =>
      _db.rpc('cancel_group_invitation', params: {'p_invitation_id': invitationId});
  Future<void> leave(int groupId) => _db.rpc('leave_split_group', params: {'p_group_id': groupId});
  Future<void> removeMember(int groupId, String userId) =>
      _db.rpc('remove_group_member', params: {'p_group_id': groupId, 'p_user': userId});
  Future<void> delete(int groupId) => _db.rpc('delete_split_group', params: {'p_group_id': groupId});
}
