import '../../family_accounts/domain/entities/family_member.dart';

/// Resolves a user id to something readable for the current viewer.
class MemberNames {
  MemberNames(List<FamilyMember> members, this.me)
      : _byId = {for (final m in members) m.userId: m};

  final String me;
  final Map<String, FamilyMember> _byId;

  String of(String userId) {
    if (userId == me) return 'You';
    final m = _byId[userId];
    if (m == null) return 'Former member';
    if (m.name != null && m.name!.trim().isNotEmpty) return m.name!.trim();
    return m.email.split('@').first;
  }

  bool isMember(String userId) => _byId.containsKey(userId);
}
