import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/expense.dart';

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    required this.onDelete,
    required this.onTap,
  });

  final Expense expense;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isExpense = expense.isExpense;
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.expenseColor,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete transaction?'),
          content: Text('Remove "${expense.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: expense.category.color.withOpacity(0.15),
            child:
                Icon(expense.category.icon, color: expense.category.color),
          ),
          title: Text(expense.title),
          subtitle: Text(
            '${expense.category.name} • ${DateFormatter.toDisplay(expense.date)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Text(
            '${isExpense ? '-' : '+'} ${CurrencyFormatter.format(expense.amount)}',
            style: TextStyle(
              color: isExpense ? AppTheme.expenseColor : AppTheme.incomeColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
