import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../domain/entities/budget.dart';
import '../providers/budget_provider.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetProvider>().load();
      context.read<CategoryProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: Consumer<BudgetProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.budgets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () => provider.load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _MonthNavigator(provider: provider),
                const SizedBox(height: 16),
                _OverallSummary(provider: provider),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Category Budgets',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                if (provider.budgets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No budgets set for this month'),
                    ),
                  )
                else
                  ...provider.budgets.map(
                    (b) => _BudgetTile(budget: b, provider: provider),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBudgetDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showBudgetDialog(BuildContext context, {Budget? existing}) {
    final provider = context.read<BudgetProvider>();
    final categories = context.read<CategoryProvider>().categories;
    final amountController = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(0) : '',
    );
    Category? selectedCategory = existing == null
        ? null
        : categories.cast<Category>().firstWhere(
            (c) => c.id == existing.categoryId,
            orElse: () => categories.first,
          );
    bool isOverall = existing?.isOverall ?? false;

    return showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Budget' : 'Edit Budget'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Overall budget'),
                    subtitle: const Text('Applies across all categories'),
                    value: isOverall,
                    onChanged: (v) => setState(() => isOverall = v),
                  ),
                  if (!isOverall)
                    DropdownButtonFormField<Category>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c.name)))
                          .toList(),
                      onChanged: (c) => setState(() => selectedCategory = c),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Monthly amount', prefixText: '\$'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null ||
                        amount <= 0 ||
                        (!isOverall && selectedCategory == null)) {
                      return;
                    }
                    final budget = Budget(
                      id: existing?.id,
                      categoryId: isOverall ? null : selectedCategory!.id,
                      month: provider.month,
                      amount: amount,
                    );
                    if (existing == null) {
                      await provider.add(budget);
                    } else {
                      await provider.edit(budget);
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({required this.provider});

  final BudgetProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: provider.previousMonth,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          DateFormat.yMMMM().format(provider.month),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        IconButton(
          onPressed: provider.nextMonth,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _OverallSummary extends StatelessWidget {
  const _OverallSummary({required this.provider});

  final BudgetProvider provider;

  @override
  Widget build(BuildContext context) {
    final overall = provider.budgets.where((b) => b.isOverall).toList();
    final budgeted =
        overall.isNotEmpty ? overall.first.amount : provider.totalBudgeted;
    final spent =
        overall.isNotEmpty ? provider.spentFor(overall.first) : provider.totalSpent;
    final ratio = budgeted > 0 ? (spent / budgeted).clamp(0.0, 1.0) : 0.0;
    final over = spent > budgeted && budgeted > 0;

    return Card(
      color: AppTheme.primaryColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(overall.isNotEmpty ? 'Overall Budget' : 'Total Budgeted',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(
              '${CurrencyFormatter.format(spent)} / ${CurrencyFormatter.format(budgeted)}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(
                  over ? AppTheme.expenseColor : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({required this.budget, required this.provider});

  final Budget budget;
  final BudgetProvider provider;

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().categories;
    final category = budget.isOverall
        ? null
        : categories.cast<Category>().firstWhere(
            (c) => c.id == budget.categoryId,
            orElse: () => categories.first,
          );
    final spent = provider.spentFor(budget);
    final ratio = budget.amount > 0 ? (spent / budget.amount).clamp(0.0, 1.0) : 0.0;
    final over = provider.isOverBudget(budget);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      (category?.color ?? AppTheme.primaryColor).withOpacity(0.15),
                  child: Icon(category?.icon ?? Icons.account_balance_wallet,
                      color: category?.color ?? AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(category?.name ?? 'Overall',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(
                  '${CurrencyFormatter.format(spent)} / ${CurrencyFormatter.format(budget.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: over ? AppTheme.expenseColor : null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => provider.remove(budget.id!),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  over ? AppTheme.expenseColor : AppTheme.primaryColor,
                ),
              ),
            ),
            if (over)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Over budget by ${CurrencyFormatter.format(spent - budget.amount)}',
                  style: TextStyle(
                      color: AppTheme.expenseColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
