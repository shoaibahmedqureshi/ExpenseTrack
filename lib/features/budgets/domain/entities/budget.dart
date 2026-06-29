class Budget {
  const Budget({
    this.id,
    this.categoryId,
    required this.month,
    required this.amount,
  });

  final int? id;

  /// Null means this budget applies across all categories ("Overall").
  final int? categoryId;

  /// Normalized to the first day of the month.
  final DateTime month;
  final double amount;

  bool get isOverall => categoryId == null;

  Budget copyWith({
    int? id,
    int? categoryId,
    DateTime? month,
    double? amount,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      month: month ?? this.month,
      amount: amount ?? this.amount,
    );
  }
}
