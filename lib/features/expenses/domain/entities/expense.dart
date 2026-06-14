import '../../../categories/domain/entities/category.dart';

enum TransactionType { income, expense }

class Expense {
  const Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    this.note,
  });

  final int? id;
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final Category category;
  final String? note;

  bool get isExpense => type == TransactionType.expense;
  bool get isIncome => type == TransactionType.income;

  Expense copyWith({
    int? id,
    String? title,
    double? amount,
    DateTime? date,
    TransactionType? type,
    Category? category,
    String? note,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      note: note ?? this.note,
    );
  }
}
