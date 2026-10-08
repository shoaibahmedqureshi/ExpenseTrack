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

/// What happened when we tried to email an invitation to someone without an account.
enum InviteEmailOutcome { delivered, notDelivered, hasAccount, alreadySent, recipientLimited, senderLimited, failed }

InviteEmailOutcome parseInviteEmailOutcome(Map<String, dynamic>? res) {
  if (res == null) return InviteEmailOutcome.failed;
  if (res['sent'] == true) return res['delivered'] == false ? InviteEmailOutcome.notDelivered : InviteEmailOutcome.delivered;
  return switch (res['reason']) {
    'has_account' => InviteEmailOutcome.hasAccount,
    'already_sent' => InviteEmailOutcome.alreadySent,
    'recipient_limited' => InviteEmailOutcome.recipientLimited,
    'sender_limited' => InviteEmailOutcome.senderLimited,
    _ => InviteEmailOutcome.failed,
  };
}

/// The line shown after inviting someone. The invitation itself exists in every case.
String describeInvite(InviteEmailOutcome outcome, String email) => switch (outcome) {
      InviteEmailOutcome.delivered => 'Invitation sent. We emailed $email with how to join.',
      InviteEmailOutcome.hasAccount => 'Invitation sent. They will see it in the app.',
      InviteEmailOutcome.alreadySent => 'Invitation sent. They were already emailed about it.',
      InviteEmailOutcome.notDelivered =>
        'Invitation created, but email sending is switched off right now. Ask them to sign up with $email.',
      InviteEmailOutcome.recipientLimited =>
        'Invitation created. We emailed that address recently, so ask them to sign up with $email.',
      InviteEmailOutcome.senderLimited =>
        'Invitation created. You have reached today\'s email limit, so ask them to sign up with $email.',
      InviteEmailOutcome.failed => 'Invitation created, but we could not email them. Ask them to sign up with $email.',
    };
