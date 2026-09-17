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
  // Year toggle only affects the top summary card's aggregate ring/number
  // — the category list below always stays scoped to the actual month
  // being navigated, since a "yearly budget per category" isn't a concept
  // this app's data model has (budgets are stored per month/category).
  // Inventing that would be new functionality, not a restyle.
  bool _isYearView = false;
  int _selectedYear = DateTime.now().year;
  ({double budgeted, double spent})? _yearSummary;
  bool _loadingYear = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final categoryProvider = context.read<CategoryProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      await budgetProvider.load();
      await categoryProvider.loadAll();
    });
  }

  Future<void> _loadYearSummary() async {
    setState(() => _loadingYear = true);
    final summary =
        await context.read<BudgetProvider>().yearSummary(_selectedYear);
    if (!mounted) return;
    setState(() {
      _yearSummary = summary;
      _loadingYear = false;
    });
  }

  void _setPeriod(bool isYear) {
    if (isYear == _isYearView) return;
    setState(() => _isYearView = isYear);
    if (isYear && _yearSummary == null) _loadYearSummary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: Consumer<BudgetProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.budgets.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              await provider.load();
              if (_isYearView) await _loadYearSummary();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PeriodSegment(isYearView: _isYearView, onChanged: _setPeriod),
                const SizedBox(height: 12),
                _MonthNavigator(provider: provider),
                const SizedBox(height: 16),
                if (_isYearView && _loadingYear)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _TotalBudgetCard(
                    provider: provider,
                    isYearView: _isYearView,
                    yearSummary: _yearSummary,
                  ),
                const SizedBox(height: 24),
                const Text('Categories',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                if (provider.budgets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No budgets set for this month'),
                    ),
                  )
                else
                  ...provider.budgets.map(
                    (b) => _BudgetTile(
                      budget: b,
                      provider: provider,
                      onEdit: () => _showBudgetDialog(context, existing: b),
                    ),
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
    // Previously, failing validation (no category picked, or an
    // empty/invalid/zero amount) just silently `return`ed with no
    // indication anything was wrong — the dialog stayed open and looked
    // like nothing happened at all, no error, nothing. That's very likely
    // why a budget never actually got created despite trying.
    String? validationError;

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
                    onChanged: (v) => setState(() {
                      isOverall = v;
                      validationError = null;
                    }),
                  ),
                  if (!isOverall)
                    DropdownButtonFormField<Category>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c.name)))
                          .toList(),
                      onChanged: (c) => setState(() {
                        selectedCategory = c;
                        validationError = null;
                      }),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Monthly amount', prefixText: '\$'),
                    onChanged: (_) {
                      if (validationError != null) {
                        setState(() => validationError = null);
                      }
                    },
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      validationError!,
                      style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                          fontSize: 13),
                    ),
                  ],
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
                    if (amount == null || amount <= 0) {
                      setState(() => validationError =
                          'Enter an amount greater than 0');
                      return;
                    }
                    if (!isOverall && selectedCategory == null) {
                      setState(() => validationError =
                          'Pick a category, or switch to Overall budget');
                      return;
                    }
                    // One budget per category (or one Overall budget) per
                    // month — without this check, tapping Save repeatedly,
                    // or two devices adding the same category's budget
                    // before either had synced, silently produced multiple
                    // rows for the same category/month that then all
                    // showed up stacked on the Budgets screen.
                    final duplicate = provider.budgets.any((b) =>
                        b.id != existing?.id &&
                        (isOverall
                            ? b.isOverall
                            : b.categoryId == selectedCategory!.id));
                    if (duplicate) {
                      setState(() => validationError = isOverall
                          ? 'An overall budget already exists for this month. Edit it instead.'
                          : 'A budget for this category already exists this month. Edit it instead.');
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
                    // provider.add()/edit() catch their own exceptions
                    // internally (see BudgetProvider._run) rather than
                    // rethrowing — previously this meant a failed insert
                    // still closed the dialog as if it had succeeded, with
                    // the actual error sitting unseen in provider.error.
                    if (provider.error != null) {
                      setState(() => validationError =
                          'Could not save: ${provider.error}');
                      return;
                    }
                    // Captured before popping this dialog — provider state
                    // is still valid, but dialogContext won't be once
                    // popped, so the follow-up dialog below has to use the
                    // outer screen context instead.
                    final autoIncrease = provider.lastAutoIncrease;
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (autoIncrease != null && context.mounted) {
                      await showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Overall budget increased'),
                          content: Text(
                            'Your category budgets now total '
                            '${CurrencyFormatter.format(autoIncrease.to)}, '
                            'more than your overall budget of '
                            '${CurrencyFormatter.format(autoIncrease.from)}. '
                            "We've increased your overall budget to match.",
                          ),
                          actions: [
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Got it'),
                            ),
                          ],
                        ),
                      );
                    }
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

class _PeriodSegment extends StatelessWidget {
  const _PeriodSegment({required this.isYearView, required this.onChanged});

  final bool isYearView;
  final void Function(bool isYear) onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, bool value) {
      final active = isYearView == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppTheme.cardColor : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? AppTheme.primaryColor : AppTheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          segment('Month', false),
          segment('Year', true),
        ],
      ),
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
          color: AppTheme.textSecondary,
        ),
        // label-md: 12px/600/0.05em, color outline, uppercase tracking-widest.
        Text(
          DateFormat.yMMMM().format(provider.month).toUpperCase(),
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 1.2,
              color: AppTheme.textSecondary),
        ),
        IconButton(
          onPressed: provider.nextMonth,
          icon: const Icon(Icons.chevron_right),
          color: AppTheme.textSecondary,
        ),
      ],
    );
  }
}

class _TotalBudgetCard extends StatelessWidget {
  const _TotalBudgetCard({
    required this.provider,
    required this.isYearView,
    required this.yearSummary,
  });

  final BudgetProvider provider;
  final bool isYearView;
  final ({double budgeted, double spent})? yearSummary;

  @override
  Widget build(BuildContext context) {
    final overall = provider.budgets.where((b) => b.isOverall).toList();
    final budgeted = isYearView
        ? (yearSummary?.budgeted ?? 0)
        : (overall.isNotEmpty ? overall.first.amount : provider.totalBudgeted);
    final spent = isYearView
        ? (yearSummary?.spent ?? 0)
        : (overall.isNotEmpty
            ? provider.spentFor(overall.first)
            : provider.totalSpent);
    final ratio = budgeted > 0 ? spent / budgeted : 0.0;
    final over = ratio > 1;
    final caution = !over && ratio >= 0.9;
    final statusColor = over
        ? AppTheme.expenseColor
        : caution
            ? AppTheme.cautionColor
            : AppTheme.primaryColor;

    final now = DateTime.now();
    final month = provider.month;
    final isCurrentMonth =
        !isYearView && now.year == month.year && now.month == month.month;
    final daysLeft = isCurrentMonth
        ? DateTime(month.year, month.month + 1, 1)
            .difference(DateTime(now.year, now.month, now.day))
            .inDays
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // label-md: 12px/600/0.05em uppercase, on-surface-variant.
                      Text(
                          (isYearView ? 'Total Budget Used This Year'
                                  : 'Total Budget Used')
                              .toUpperCase(),
                          style: const TextStyle(
                              color: AppTheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6)),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          // display-lg: 32px/700/-0.02em, color primary.
                          Text(
                            CurrencyFormatter.format(spent),
                            style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.6),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 6, bottom: 4),
                            child: Text(
                              '/ ${CurrencyFormatter.format(budgeted)}',
                              style: const TextStyle(
                                  color: AppTheme.onSurfaceVariant,
                                  fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _TotalRing(ratio: ratio, color: statusColor),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  over
                      ? Icons.trending_up
                      : caution
                          ? Icons.warning_amber_rounded
                          : Icons.trending_up,
                  size: 18,
                  color: statusColor,
                ),
                const SizedBox(width: 6),
                // Expanded+ellipsis: "$caution/status ($daysLeft days
                // remaining)" has no fixed upper bound on daysLeft's digit
                // count or the card's width (e.g. a narrow phone), and an
                // unwrapped Text here has no width limit to shrink into.
                Expanded(
                  child: Text(
                    over
                        ? 'Over budget'
                        : daysLeft != null
                            ? '${caution ? 'Near limit' : 'On track'} ($daysLeft days remaining)'
                            : (caution ? 'Near limit' : 'On track'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRing extends StatelessWidget {
  const _TotalRing({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = (ratio * 100).round();
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation(Color(0xFFEFEDED)),
            ),
          ),
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: ratio.clamp(0, 1).toDouble(),
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text('$pct%',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    required this.budget,
    required this.provider,
    required this.onEdit,
  });

  final Budget budget;
  final BudgetProvider provider;
  final VoidCallback onEdit;

  Future<void> _confirmDelete(BuildContext context) async {
    final categories = context.read<CategoryProvider>().categories;
    final category = budget.isOverall
        ? null
        : categories.cast<Category>().firstWhere(
            (c) => c.id == budget.categoryId,
            orElse: () => categories.first,
          );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete budget?'),
        content: Text(
          'This removes the ${category?.name ?? 'Overall'} budget for this '
          'month on every synced device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.expenseColor),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) provider.remove(budget.id!);
  }

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
    final ratio = budget.amount > 0 ? spent / budget.amount : 0.0;
    final over = provider.isOverBudget(budget);
    final caution = !over && ratio >= 0.9;
    final statusColor = over
        ? AppTheme.expenseColor
        : caution
            ? AppTheme.cautionColor
            : AppTheme.primaryColor;
    final iconColor = over
        ? AppTheme.expenseColor
        : (category?.color ?? AppTheme.primaryColor);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: iconColor.withOpacity(0.15),
                  child: Icon(category?.icon ?? Icons.account_balance_wallet,
                      color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(category?.name ?? 'Overall',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: AppTheme.textPrimary)),
                      Text(
                        over
                            ? 'Over by ${CurrencyFormatter.format(spent - budget.amount)}'
                            : 'Remaining: ${CurrencyFormatter.format(budget.amount - spent)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              over ? FontWeight.w700 : FontWeight.w400,
                          color: over
                              ? AppTheme.expenseColor
                              : AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Flexible (not a bare Column) so very large formatted
                // amounts shrink-to-fit instead of forcing the row past
                // its available width — an unbounded natural-width Column
                // here is exactly what caused the reported overflow.
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CurrencyFormatter.format(spent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: over ? AppTheme.expenseColor : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'of ${CurrencyFormatter.formatCompact(budget.amount)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                // A single compact menu instead of two full-sized
                // IconButtons keeps this row's fixed-width footprint the
                // same as when there was only ever a delete button.
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      _confirmDelete(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: AppTheme.expenseColor),
                          SizedBox(width: 8),
                          Text('Delete',
                              style:
                                  TextStyle(color: AppTheme.expenseColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio.clamp(0, 1).toDouble(),
                minHeight: 10,
                backgroundColor: AppTheme.surfaceContainer,
                valueColor: AlwaysStoppedAnimation(statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
