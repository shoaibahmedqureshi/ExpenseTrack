import '../../expense_split/domain/split_models.dart';

const maxGroupMembers = 20;

class SplitGroup {
  const SplitGroup({required this.id, required this.name, required this.isOwner});
  final int id;
  final String name;
  final bool isOwner;

  Ledger get ledger => Ledger(LedgerKind.group, id, name);
}

class GroupInvitation {
  const GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.email,
    required this.createdAt,
  });
  final int id;
  final int groupId;
  final String groupName;
  final String email;
  final DateTime createdAt;

  factory GroupInvitation.fromJson(Map<String, dynamic> j) => GroupInvitation(
        id: j['id'] as int,
        groupId: j['group_id'] as int,
        groupName: ((j['split_groups'] as Map?)?['name'] as String?) ?? 'a group',
        email: j['email'] as String,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );
}

/// Which ledgers (the family, and each group) a person can split in, in display order.
List<Ledger> availableLedgers({Ledger? family, required List<SplitGroup> groups}) =>
    [if (family != null) family, for (final g in groups) g.ledger];

/// Keeps the current choice while it is still available, otherwise falls back to the first one.
Ledger? chooseLedger(List<Ledger> available, Ledger? current) {
  if (current != null && available.contains(current)) return current;
  return available.isEmpty ? null : available.first;
}
