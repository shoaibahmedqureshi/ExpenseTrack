import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../../../expense_split/domain/split_models.dart';
import '../../data/split_group_repository.dart';
import '../../domain/group_models.dart';

class SplitGroupProvider extends ChangeNotifier {
  SplitGroupProvider({required this.repository});
  final SplitGroupRepository repository;

  List<SplitGroup> _groups = [];
  List<GroupInvitation> _invitations = [];
  final Map<int, List<LedgerMember>> _members = {};
  final Map<int, List<GroupInvitation>> _sent = {};
  bool _loading = false;
  String? _error;
  String? _inviteNote;

  List<SplitGroup> get groups => _groups;
  List<GroupInvitation> get invitations => _invitations;
  bool get isLoading => _loading;
  String? get error => _error;

  /// What to tell the user after the last successful [invite].
  String? get inviteNote => _inviteNote;
  List<LedgerMember> membersOf(int groupId) => _members[groupId] ?? const [];
  List<GroupInvitation> sentInvitationsOf(int groupId) => _sent[groupId] ?? const [];
  SplitGroup? byId(int id) => _groups.where((g) => g.id == id).firstOrNull;

  String _msg(Object e) => e is PostgrestException ? e.message : e.toString().replaceFirst('Exception: ', '');

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      notifyListeners();
    }
    try {
      final r = await Future.wait([repository.myGroups(), repository.myInvitations()]);
      _groups = r[0] as List<SplitGroup>;
      _invitations = r[1] as List<GroupInvitation>;
      _members.removeWhere((id, _) => !_groups.any((g) => g.id == id));
      _error = null;
    } catch (e) {
      _error = _msg(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Members and pending invitations for one group (the detail screen and the split form need them).
  Future<void> loadGroup(int groupId) async {
    try {
      final r = await Future.wait([repository.members(groupId), repository.sentInvitations(groupId)]);
      _members[groupId] = r[0] as List<LedgerMember>;
      _sent[groupId] = r[1] as List<GroupInvitation>;
      _error = null;
    } catch (e) {
      _error = _msg(e);
    }
    notifyListeners();
  }

  Future<bool> _do(Future<void> Function() action, {int? reloadGroup}) async {
    try {
      await action();
      _error = null;
      await load(silent: true);
      if (reloadGroup != null && _groups.any((g) => g.id == reloadGroup)) await loadGroup(reloadGroup);
      return true;
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
      return false;
    }
  }

  /// Returns the new group's id, or null on failure (see [error]).
  Future<int?> create(String name) async {
    try {
      final id = await repository.create(name.trim());
      _error = null;
      await load(silent: true);
      await loadGroup(id);
      return id;
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> rename(int groupId, String name) => _do(() => repository.rename(groupId, name.trim()));
  Future<bool> invite(int groupId, String email) async {
    final address = email.trim();
    _inviteNote = null;
    int? invitationId;
    final ok = await _do(() async => invitationId = await repository.invite(groupId, address), reloadGroup: groupId);
    if (!ok || invitationId == null) return false;
    final outcome = await repository.sendInviteEmail(invitationId!);
    _inviteNote = describeInvite(outcome, address.toLowerCase());
    notifyListeners();
    return true;
  }
  Future<bool> respond(GroupInvitation i, bool accept) => _do(() => repository.respond(i.id, accept));
  Future<bool> cancelInvitation(int groupId, GroupInvitation i) =>
      _do(() => repository.cancelInvitation(i.id), reloadGroup: groupId);
  Future<bool> leave(int groupId) => _do(() => repository.leave(groupId));
  Future<bool> removeMember(int groupId, String userId) =>
      _do(() => repository.removeMember(groupId, userId), reloadGroup: groupId);
  Future<bool> delete(int groupId) => _do(() => repository.delete(groupId));

  void clear() {
    _groups = [];
    _invitations = [];
    _members.clear();
    _sent.clear();
    _loading = false;
    _error = null;
    notifyListeners();
  }
}
