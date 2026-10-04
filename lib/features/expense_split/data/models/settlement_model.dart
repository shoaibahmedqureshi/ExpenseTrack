import '../../domain/entities/settlement.dart';

class SettlementModel extends Settlement {
  const SettlementModel({
    required super.id,
    required super.familyGroupId,
    required super.fromMemberId,
    required super.toMemberId,
    required super.amount,
    super.currency = 'PKR',
    super.description,
    super.isPaid = false,
    required super.createdAt,
    super.settledAt,
  });

  factory SettlementModel.fromJson(Map<String, dynamic> json) {
    return SettlementModel(
      id: json['id'] as String,
      familyGroupId: json['family_group_id'] as String,
      fromMemberId: json['from_member_id'] as String,
      toMemberId: json['to_member_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'PKR',
      description: json['description'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      settledAt: json['settled_at'] != null ? DateTime.parse(json['settled_at'] as String) : null,
    );
  }

  factory SettlementModel.fromEntity(Settlement entity) {
    return SettlementModel(
      id: entity.id,
      familyGroupId: entity.familyGroupId,
      fromMemberId: entity.fromMemberId,
      toMemberId: entity.toMemberId,
      amount: entity.amount,
      currency: entity.currency,
      description: entity.description,
      isPaid: entity.isPaid,
      createdAt: entity.createdAt,
      settledAt: entity.settledAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_group_id': familyGroupId,
      'from_member_id': fromMemberId,
      'to_member_id': toMemberId,
      'amount': amount,
      'currency': currency,
      'description': description,
      'is_paid': isPaid,
      'created_at': createdAt.toIso8601String(),
      'settled_at': settledAt?.toIso8601String(),
    };
  }
}
