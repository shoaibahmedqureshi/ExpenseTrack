import '../../domain/entities/budget.dart';

class BudgetModel extends Budget {
  const BudgetModel({
    super.id,
    super.categoryId,
    required super.month,
    required super.amount,
  });

  factory BudgetModel.fromMap(Map<String, dynamic> map) => BudgetModel(
        id: map['id'] as int?,
        categoryId: map['category_id'] as int?,
        month: DateTime.parse(map['month'] as String),
        amount: (map['amount'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'category_id': categoryId,
        'month': DateTime(month.year, month.month, 1).toIso8601String(),
        'amount': amount,
      };

  factory BudgetModel.fromEntity(Budget budget) => BudgetModel(
        id: budget.id,
        categoryId: budget.categoryId,
        month: budget.month,
        amount: budget.amount,
      );
}
