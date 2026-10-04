import '../../domain/entities/expense_split.dart';

class ExpenseSplitModel extends ExpenseSplit {
  const ExpenseSplitModel({
    required super.id,
    required super.expenseId,
    required super.familyGroupId,
    required super.paidByMemberId,
    required super.splitAmounts,
    super.currency = 'PKR',
    required super.createdAt,
    super.description,
    super.isSettled = false,
    super.settledDate,
  });

  factory ExpenseSplitModel.fromJson(Map<String, dynamic> json) {
    final splitAmountsMap = (json['split_amounts'] as Map<String, dynamic>?)
        ?.map((key, value) => MapEntry(key, (value as num).toDouble()))
        ?? {};

    return ExpenseSplitModel(
      id: json['id'] as String,
      expenseId: json['expense_id'] as String,
      familyGroupId: json['family_group_id'] as String,
      paidByMemberId: json['paid_by_member_id'] as String,
      splitAmounts: splitAmountsMap,
      currency: json['currency'] as String? ?? 'PKR',
      createdAt: DateTime.parse(json['created_at'] as String),
      description: json['description'] as String?,
      isSettled: json['is_settled'] as bool? ?? false,
      settledDate: json['settled_date'] != null ? DateTime.parse(json['settled_date'] as String) : null,
    );
  }

  factory ExpenseSplitModel.fromEntity(ExpenseSplit entity) {
    return ExpenseSplitModel(
      id: entity.id,
      expenseId: entity.expenseId,
      familyGroupId: entity.familyGroupId,
      paidByMemberId: entity.paidByMemberId,
      splitAmounts: entity.splitAmounts,
      currency: entity.currency,
      createdAt: entity.createdAt,
      description: entity.description,
      isSettled: entity.isSettled,
      settledDate: entity.settledDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expense_id': expenseId,
      'family_group_id': familyGroupId,
      'paid_by_member_id': paidByMemberId,
      'split_amounts': splitAmounts,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
      'description': description,
      'is_settled': isSettled,
      'settled_date': settledDate?.toIso8601String(),
    };
  }
}
