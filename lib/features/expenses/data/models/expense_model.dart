import '../../../categories/data/models/category_model.dart';
import '../../domain/entities/expense.dart';

class ExpenseModel extends Expense {
  const ExpenseModel({
    super.id,
    required super.title,
    required super.amount,
    required super.date,
    required super.type,
    required super.category,
    super.note,
  });

  factory ExpenseModel.fromMap(
    Map<String, dynamic> map,
    CategoryModel category,
  ) =>
      ExpenseModel(
        id: map['id'] as int?,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: DateTime.parse(map['date'] as String),
        type: TransactionType.values[map['type'] as int],
        category: category,
        note: map['note'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'type': type.index,
        'category_id': category.id,
        'note': note,
      };

  factory ExpenseModel.fromEntity(Expense expense) => ExpenseModel(
        id: expense.id,
        title: expense.title,
        amount: expense.amount,
        date: expense.date,
        type: expense.type,
        category: expense.category,
        note: expense.note,
      );
}
