enum SplitType {
  equal('Equal'),
  amount('By amount'),
  percent('By percentage');

  const SplitType(this.label);
  final String label;

  static SplitType parse(String s) =>
      SplitType.values.firstWhere((t) => t.name == s, orElse: () => SplitType.equal);
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
    required this.paidBy,
    required this.createdBy,
    required this.description,
    required this.totalCents,
    required this.type,
    required this.createdAt,
    required this.shares,
  });

  final int id;
  final int familyId;
  final String paidBy;
  final String createdBy;
  final String description;
  final int totalCents;
  final SplitType type;
  final DateTime createdAt;
  final List<SplitShare> shares;

  factory ExpenseSplit.fromJson(Map<String, dynamic> j) => ExpenseSplit(
        id: j['id'] as int,
        familyId: j['family_id'] as int,
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
    required this.fromUser,
    required this.toUser,
    required this.cents,
    required this.createdBy,
    required this.createdAt,
  });

  final int id;
  final int familyId;
  final String fromUser;
  final String toUser;
  final int cents;
  final String createdBy;
  final DateTime createdAt;

  factory SplitSettlement.fromJson(Map<String, dynamic> j) => SplitSettlement(
        id: j['id'] as int,
        familyId: j['family_id'] as int,
        fromUser: j['from_user'] as String,
        toUser: j['to_user'] as String,
        cents: _cents(j['amount']),
        createdBy: j['created_by'] as String,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );
}
