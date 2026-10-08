enum SplitType {
  equal('Equal'),
  amount('By amount'),
  percent('By percentage');

  const SplitType(this.label);
  final String label;

  static SplitType parse(String s) =>
      SplitType.values.firstWhere((t) => t.name == s, orElse: () => SplitType.equal);
}

/// A place where costs are shared: a family or a split group.
enum LedgerKind {
  family('family', 'family_id'),
  group('group', 'group_id');

  const LedgerKind(this.key, this.column);
  final String key;
  final String column;
}

class Ledger {
  const Ledger(this.kind, this.id, this.name);
  final LedgerKind kind;
  final int id;
  final String name;

  @override
  bool operator ==(Object other) => other is Ledger && other.kind == kind && other.id == id;
  @override
  int get hashCode => Object.hash(kind, id);
}

/// Where the viewer stands in one ledger: positive = owed money, negative = owes.
class LedgerBalance {
  const LedgerBalance({required this.ledger, required this.netCents, required this.hasActivity});
  final Ledger ledger;
  final int netCents;
  final bool hasActivity;

  factory LedgerBalance.fromJson(Map<String, dynamic> j) => LedgerBalance(
        ledger: Ledger(
          j['kind'] == 'group' ? LedgerKind.group : LedgerKind.family,
          j['id'] as int,
          (j['name'] as String?) ?? '',
        ),
        netCents: _cents(j['net']),
        hasActivity: j['has_activity'] == true,
      );
}

/// Someone in a ledger, as needed to show names and pick people for a split.
class LedgerMember {
  const LedgerMember({required this.userId, required this.email, this.name, this.isOwner = false});
  final String userId;
  final String email;
  final String? name;
  final bool isOwner;

  factory LedgerMember.fromJson(Map<String, dynamic> j) => LedgerMember(
        userId: j['user_id'] as String,
        email: (j['email'] as String?) ?? '',
        name: j['name'] as String?,
        isOwner: j['role'] == 'owner',
      );
}

int _cents(Object? numeric) => (((numeric as num?) ?? 0) * 100).round();

class SplitShare {
  const SplitShare({required this.userId, required this.cents, this.percent});
  final String userId;
  final int cents;
  final double? percent;

  factory SplitShare.fromJson(Map<String, dynamic> j) => SplitShare(
        userId: j['user_id'] as String,
        cents: _cents(j['amount']),
        percent: (j['percent'] as num?)?.toDouble(),
      );
}

class ExpenseSplit {
  const ExpenseSplit({
    required this.id,
    required this.familyId,
    required this.groupId,
    required this.paidBy,
    required this.createdBy,
    required this.description,
    required this.totalCents,
    required this.type,
    required this.createdAt,
    required this.shares,
  });

  final int id;
  final int? familyId;
  final int? groupId;
  final String paidBy;
  final String createdBy;
  final String description;
  final int totalCents;
  final SplitType type;
  final DateTime createdAt;
  final List<SplitShare> shares;

  factory ExpenseSplit.fromJson(Map<String, dynamic> j) => ExpenseSplit(
        id: j['id'] as int,
        familyId: j['family_id'] as int?,
        groupId: j['group_id'] as int?,
        paidBy: j['paid_by'] as String,
        createdBy: j['created_by'] as String,
        description: j['description'] as String,
        totalCents: _cents(j['total_amount']),
        type: SplitType.parse(j['split_type'] as String),
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        shares: ((j['expense_split_shares'] as List?) ?? const [])
            .map((s) => SplitShare.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
      );
}

class SplitSettlement {
  const SplitSettlement({
    required this.id,
    required this.familyId,
    required this.groupId,
    required this.fromUser,
    required this.toUser,
    required this.cents,
    required this.createdBy,
    required this.createdAt,
  });

  final int id;
  final int? familyId;
  final int? groupId;
  final String fromUser;
  final String toUser;
  final int cents;
  final String createdBy;
  final DateTime createdAt;

  factory SplitSettlement.fromJson(Map<String, dynamic> j) => SplitSettlement(
        id: j['id'] as int,
        familyId: j['family_id'] as int?,
        groupId: j['group_id'] as int?,
        fromUser: j['from_user'] as String,
        toUser: j['to_user'] as String,
        cents: _cents(j['amount']),
        createdBy: j['created_by'] as String,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );
}
