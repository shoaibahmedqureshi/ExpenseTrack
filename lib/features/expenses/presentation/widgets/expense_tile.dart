import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/expense.dart';

// Flat row rather than its own Card — the reference groups a day's
// transactions into one shared card with bordered rows inside, not a
// separate card per transaction. The caller (ExpenseListScreen) provides
// that shared card/border; this widget only owns the swipe-to-delete and
// row content.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    required this.onDelete,
    required this.onTap,
    this.showBottomBorder = true,
  });

  final Expense expense;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final bool showBottomBorder;

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
      child: InkWell(
        onTap: onTap,
        child: Container(
          // p-lg: 24px.
          padding: const EdgeInsets.all(24),
          decoration: showBottomBorder
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: AppTheme.outlineVariant.withOpacity(0.3)),
                  ),
                )
              : null,
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: expense.category.color.withOpacity(0.1),
                child:
                    Icon(expense.category.icon, color: expense.category.color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The reference's title only sets `font-headline-sm`,
                    // which is a font-FAMILY utility, not a size one — it
                    // has no text-size class at all, so it renders at the
                    // base body size (~16px), not the 20px "headline-sm"
                    // token. 20px (what this used before) was reading too
                    // much into the class name.
                    Text(expense.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    // label-md: 12px/600/0.05em, color outline.
                    Text(
                      '${DateFormatter.toDisplay(expense.date)} • ${expense.category.name}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              // Only income is colored (tertiary/green) per the reference —
              // regular expenses stay on-surface (black), not red.
              Text(
                '${isExpense ? '-' : '+'} ${CurrencyFormatter.format(expense.amount)}',
                style: TextStyle(
                  color: isExpense ? AppTheme.textPrimary : AppTheme.incomeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
