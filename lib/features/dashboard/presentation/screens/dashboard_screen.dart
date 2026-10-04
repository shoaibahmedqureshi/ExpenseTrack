import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../budgets/domain/entities/budget.dart';
import '../../../budgets/presentation/providers/budget_provider.dart';
import '../../../budgets/presentation/screens/budgets_screen.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../../../expenses/presentation/screens/expense_list_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../sync/sync_service.dart';

// Kept deliberately short — the Dashboard is meant to be a glanceable
// summary, not a second copy of the Transactions tab. "Show more" hands
// off to the real paginated list rather than growing this one.
const _recentTransactionCount = 4;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onSeeAllTransactions});

  /// Switches MainShell to the Transactions tab. Falls back to pushing
  /// ExpenseListScreen directly if not provided (e.g. if this screen is
  /// ever used outside MainShell), so this stays usable standalone.
  final VoidCallback? onSeeAllTransactions;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isYearView = false;
  int _selectedYear = DateTime.now().year;
  ({double budgeted, double spent})? _yearSummary;
  bool _loadingYear = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().loadAll();
      context.read<BudgetProvider>().load();
      context.read<CategoryProvider>().loadAll();
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

  void _previousPeriod() {
    if (_isYearView) {
      setState(() {
        _selectedYear -= 1;
        _yearSummary = null;
      });
      _loadYearSummary();
    } else {
      context.read<BudgetProvider>().previousMonth();
    }
  }

  void _nextPeriod() {
    if (_isYearView) {
      setState(() {
        _selectedYear += 1;
        _yearSummary = null;
      });
      _loadYearSummary();
    } else {
      context.read<BudgetProvider>().nextMonth();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Extrabold on top of the shared 24px/600 AppBarTheme default —
        // matches the reference's Dashboard-specific weight override (the
        // other 3 screens keep the plain 600 weight).
        title: const Text('Dashboard',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final initial = (auth.profile?.name?.isNotEmpty == true
                      ? auth.profile!.name![0]
                      : auth.profile?.email[0] ?? '?')
                  .toUpperCase();
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.onPrimaryContainer,
                    child: Text(initial,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                            fontSize: 14)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer3<ExpenseProvider, BudgetProvider, CategoryProvider>(
        builder:
            (context, expenseProvider, budgetProvider, categoryProvider, _) {
          // Full-screen loader only when there's truly nothing to show yet
          // (the very first load). Once hasLoadedOnce flips true, the
          // screen must never go blank again — a background sync firing
          // later gets a subtle top indicator instead.
          if (!expenseProvider.hasLoadedOnce) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
              ),
            );
          }
          return ValueListenableBuilder<bool>(
            valueListenable: SyncService.isSyncingNotifier,
            builder: (context, isSyncing, child) {
              return Column(
                children: [
                  if (isSyncing)
                    const LinearProgressIndicator(
                      minHeight: 3,
                      valueColor:
                          AlwaysStoppedAnimation(AppTheme.primaryColor),
                    ),
                  Expanded(child: child!),
                ],
              );
            },
            child: RefreshIndicator(
              onRefresh: () async {
                await expenseProvider.loadAll();
                await budgetProvider.load();
                if (_isYearView) await _loadYearSummary();
              },
              child: _DashboardBody(
                expenseProvider: expenseProvider,
                budgetProvider: budgetProvider,
                categoryProvider: categoryProvider,
                isYearView: _isYearView,
                selectedYear: _selectedYear,
                yearSummary: _yearSummary,
                loadingYear: _loadingYear,
                onSetPeriod: _setPeriod,
                onPrevious: _previousPeriod,
                onNext: _nextPeriod,
                onSeeAllTransactions: widget.onSeeAllTransactions,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.expenseProvider,
    required this.budgetProvider,
    required this.categoryProvider,
    required this.isYearView,
    required this.selectedYear,
    required this.yearSummary,
    required this.loadingYear,
    required this.onSetPeriod,
    required this.onPrevious,
    required this.onNext,
    required this.onSeeAllTransactions,
  });

  final ExpenseProvider expenseProvider;
  final BudgetProvider budgetProvider;
  final CategoryProvider categoryProvider;
  final bool isYearView;
  final int selectedYear;
  final ({double budgeted, double spent})? yearSummary;
  final VoidCallback? onSeeAllTransactions;
  final bool loadingYear;
  final void Function(bool isYear) onSetPeriod;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final month = budgetProvider.month;
    final monthStart = DateTime(month.year, month.month, 1);
    final nextMonthStart = DateTime(month.year, month.month + 1, 1);
    final lastMonthStart = DateTime(month.year, month.month - 1, 1);

    final periodStart = isYearView ? DateTime(selectedYear, 1, 1) : monthStart;
    final periodEnd =
        isYearView ? DateTime(selectedYear + 1, 1, 1) : nextMonthStart;

    final income = expenseProvider.incomeIn(periodStart, periodEnd);
    final expense = expenseProvider.expenseIn(periodStart, periodEnd);
    final balance = income - expense;

    final comparisonExpense = isYearView
        ? expenseProvider.expenseIn(
            DateTime(selectedYear - 1, 1, 1), DateTime(selectedYear, 1, 1))
        : expenseProvider.expenseIn(lastMonthStart, monthStart);
    final deltaPct = comparisonExpense > 0
        ? ((expense - comparisonExpense) / comparisonExpense * 100)
        : null;

    final budgeted =
        isYearView ? (yearSummary?.budgeted ?? 0) : budgetProvider.totalBudgeted;
    final spent = isYearView ? (yearSummary?.spent ?? 0) : budgetProvider.totalSpent;
    final hasBudget = budgeted > 0;

    final periodLabel = isYearView
        ? '$selectedYear'
        : DateFormat.yMMMM().format(month).toUpperCase();

    final now = DateTime.now();
    final isCurrentMonth =
        !isYearView && now.year == month.year && now.month == month.month;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final name = auth.profile?.name;
            return Text(
              (name != null && name.isNotEmpty) ? 'Hi, $name' : 'Welcome back',
              // headline-sm: 20px/600, color on-surface-variant.
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceVariant),
            );
          },
        ),
        const SizedBox(height: 14),
        _PeriodSegment(isYearView: isYearView, onChanged: onSetPeriod),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
              color: AppTheme.textSecondary,
            ),
            // label-sm (12px/600) with the "tracking-widest" (0.1em)
            // override used specifically on the date selector.
            Text(periodLabel,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.2)),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              color: AppTheme.textSecondary,
            ),
          ],
        ),
        _BalanceHero(balance: balance, deltaPct: deltaPct),
        const SizedBox(height: 16),
        _IncomeExpenseRow(income: income, expense: expense),
        const SizedBox(height: 18),
        if (isYearView && loadingYear)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (hasBudget)
          _BudgetCard(
            budgeted: budgeted,
            spent: spent,
            isYearView: isYearView,
            budgetProvider: budgetProvider,
            categoryProvider: categoryProvider,
            expensesInPeriod:
                expenseProvider.inRange(periodStart, periodEnd),
          )
        else
          _NoBudgetCard(
            isYearView: isYearView,
            expensesInPeriod:
                expenseProvider.inRange(periodStart, periodEnd),
          ),
        if (isCurrentMonth) ...[
          const SizedBox(height: 14),
          _BurnRateLine(monthStart: monthStart, spentSoFar: expense),
        ],
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // headline-md: 24px/600, color on-surface.
            const Text('Recent Transactions',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            TextButton(
              onPressed: onSeeAllTransactions ??
                  () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ExpenseListScreen()),
                      ),
              child: const Text('View all',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ..._buildGroupedTransactions(
            expenseProvider.expenses.take(_recentTransactionCount).toList()),
      ],
    );
  }

  List<Widget> _buildGroupedTransactions(List<Expense> recent) {
    if (recent.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('No transactions yet.',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ),
      ];
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String labelFor(DateTime date) {
      final d = DateTime(date.year, date.month, date.day);
      if (d == today) return 'Today';
      if (d == yesterday) return 'Yesterday';
      return 'Earlier';
    }

    final widgets = <Widget>[];
    String? lastLabel;
    for (final expense in recent) {
      final label = labelFor(expense.date);
      if (label != lastLabel) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            label.toUpperCase(),
            // label-sm: 12px/600/0.05em (tracking-wider).
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.6),
          ),
        ));
        lastLabel = label;
      }
      widgets.add(_TransactionTile(expense: expense));
    }
    return widgets;
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
              // Active pill = "bg-surface" (the page background color) —
              // it reads as white-ish against the darker gray track below,
              // not literally pure white.
              color: active ? AppTheme.backgroundColor : Colors.transparent,
              borderRadius: BorderRadius.circular(17),
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
                color: active ? AppTheme.textPrimary : AppTheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        // "surface-container" track — a distinct, slightly darker gray
        // than the page background so the active pill visibly sits above.
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
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

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.balance, required this.deltaPct});

  final double balance;
  final double? deltaPct;

  @override
  Widget build(BuildContext context) {
    // Framed as spending trend, not "good/bad balance" trend — a rise
    // means the user spent more than the comparison period, which is
    // worth flagging regardless of whether their overall balance is
    // still positive.
    final spendingRose = (deltaPct ?? 0) > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          // label-md: 14px/500/0.01em, color on-surface-variant.
          Text('Balance this period',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.onSurfaceVariant,
                  letterSpacing: 0.14)),
          const SizedBox(height: 8),
          // display: 40px/700/-0.02em.
          Text(
            CurrencyFormatter.format(balance),
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: balance < 0 ? AppTheme.expenseColor : AppTheme.textPrimary,
            ),
          ),
          if (deltaPct != null) ...[
            const SizedBox(height: 8),
            // Pill badge (inline-flex, tinted bg, rounded-full) rather
            // than a bare icon+text row.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: (spendingRose
                        ? AppTheme.expenseColor
                        : AppTheme.tertiaryContainerText)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    spendingRose ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                    color: spendingRose
                        ? AppTheme.expenseColor
                        : AppTheme.tertiaryContainerText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${deltaPct!.abs().toStringAsFixed(0)}% ${spendingRose ? 'more' : 'less'} spending',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: spendingRose
                          ? AppTheme.expenseColor
                          : AppTheme.tertiaryContainerText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IncomeExpenseRow extends StatelessWidget {
  const _IncomeExpenseRow({required this.income, required this.expense});

  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    // Vertically-stacked grid cards (icon centered on top, label, then
    // amount) rather than a horizontal icon-left row — matches the
    // reference's two-card grid exactly.
    Widget stat(IconData icon, Color color, String label, double amount) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppTheme.outlineVariant.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: AppTheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                CurrencyFormatter.format(amount),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        stat(Icons.arrow_downward, AppTheme.incomeColor, 'Income', income),
        const SizedBox(width: 12),
        stat(Icons.arrow_upward, AppTheme.expenseColor, 'Expenses', expense),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budgeted,
    required this.spent,
    required this.isYearView,
    required this.budgetProvider,
    required this.categoryProvider,
    required this.expensesInPeriod,
  });

  final double budgeted;
  final double spent;
  final bool isYearView;
  final BudgetProvider budgetProvider;
  final CategoryProvider categoryProvider;
  final List<Expense> expensesInPeriod;

  Category? _categoryFor(Budget b) {
    if (b.isOverall) return null;
    final categories = categoryProvider.categories;
    if (categories.isEmpty) return null;
    return categories.cast<Category>().firstWhere(
          (c) => c.id == b.categoryId,
          orElse: () => categories.first,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // headline-sm: 20px/600, color on-surface-variant.
            Text(isYearView ? 'Budget this year' : 'Budget this month',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _BudgetRing(budgeted: budgeted, spent: spent),
                const SizedBox(width: 32),
                Expanded(
                  child: isYearView
                      ? _CategoryAmountList(
                          title: 'Top categories',
                          entries: _topCategories(expensesInPeriod))
                      : _BudgetLegend(
                          budgets: budgetProvider.budgets
                              .where((b) => !b.isOverall)
                              .toList(),
                          budgetProvider: budgetProvider,
                          categoryFor: _categoryFor,
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

List<MapEntry<Category, double>> _topCategories(List<Expense> expenses,
    {int take = 3}) {
  final map = <Category, double>{};
  for (final e in expenses.where((e) => e.isExpense)) {
    map[e.category] = (map[e.category] ?? 0) + e.amount;
  }
  final sorted = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(take).toList();
}

class _BudgetRing extends StatelessWidget {
  const _BudgetRing({required this.budgeted, required this.spent});

  final double budgeted;
  final double spent;

  @override
  Widget build(BuildContext context) {
    final ratio = budgeted > 0 ? spent / budgeted : 0.0;
    final over = ratio > 1;
    final pct = (ratio * 100).round();
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(
            width: 128,
            height: 128,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 12,
              valueColor: AlwaysStoppedAnimation(Color(0xFFE9E9E9)),
            ),
          ),
          SizedBox(
            width: 128,
            height: 128,
            child: CircularProgressIndicator(
              value: ratio.clamp(0, 1).toDouble(),
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation(
                over ? AppTheme.expenseColor : AppTheme.primaryColor,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // headline-md: 24px/600.
              Text('$pct%',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              // label-sm: 12px/600, color outline.
              Text(
                '${CurrencyFormatter.formatCompact(spent)}/${CurrencyFormatter.formatCompact(budgeted)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetLegend extends StatelessWidget {
  const _BudgetLegend({
    required this.budgets,
    required this.budgetProvider,
    required this.categoryFor,
  });

  final List<Budget> budgets;
  final BudgetProvider budgetProvider;
  final Category? Function(Budget) categoryFor;

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) {
      return const Text('No category budgets set',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary));
    }
    final sorted = [...budgets]
      ..sort((a, b) =>
          budgetProvider.spentFor(b).compareTo(budgetProvider.spentFor(a)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: sorted.take(4).map((b) {
        final category = categoryFor(b);
        final over = budgetProvider.isOverBudget(b);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: over ? AppTheme.expenseColor : (category?.color ?? AppTheme.primaryColor),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // label-md: 14px/500, color on-surface-variant.
              Expanded(
                child: Text(category?.name ?? 'Overall',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onSurfaceVariant)),
              ),
              Text(
                CurrencyFormatter.formatCompact(budgetProvider.spentFor(b)),
                style: TextStyle(
                  fontSize: 14,
                  color: over ? AppTheme.expenseColor : AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CategoryAmountList extends StatelessWidget {
  const _CategoryAmountList({required this.title, required this.entries});

  final String title;
  final List<MapEntry<Category, double>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text('No spending in this period',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: entry.key.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(entry.key.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onSurfaceVariant)),
              ),
              Text(
                CurrencyFormatter.formatCompact(entry.value),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _NoBudgetCard extends StatelessWidget {
  const _NoBudgetCard({
    required this.isYearView,
    required this.expensesInPeriod,
  });

  final bool isYearView;
  final List<Expense> expensesInPeriod;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_outline,
                    size: 20, color: AppTheme.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isYearView
                        ? 'No budget set for this year'
                        : 'No budget set for this month',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BudgetsScreen()),
                  ),
                  child: const Text('Set budget'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _CategoryAmountList(
              title: 'Top categories',
              entries: _topCategories(expensesInPeriod),
            ),
          ],
        ),
      ),
    );
  }
}

class _BurnRateLine extends StatelessWidget {
  const _BurnRateLine({required this.monthStart, required this.spentSoFar});

  final DateTime monthStart;
  final double spentSoFar;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final daysLeft = monthEnd.difference(DateTime(now.year, now.month, now.day)).inDays;
    final daysElapsed = now.day;
    final average = daysElapsed > 0 ? spentSoFar / daysElapsed : 0;

    return Row(
      children: [
        const Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$daysLeft days left · averaging ${CurrencyFormatter.format(average.toDouble())}/day',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final isExpense = expense.isExpense;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.outlineVariant.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: expense.category.color.withOpacity(0.1),
          child: Icon(expense.category.icon, color: expense.category.color),
        ),
        title: Text(expense.title,
            style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary)),
        subtitle: Text(expense.category.name,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        trailing: Text(
          '${isExpense ? '-' : '+'} ${CurrencyFormatter.format(expense.amount)}',
          style: TextStyle(
            fontSize: 16,
            color: isExpense ? AppTheme.expenseColor : AppTheme.incomeColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
