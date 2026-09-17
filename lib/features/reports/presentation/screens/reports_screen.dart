import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../data/report_exporter.dart';
import '../providers/reports_provider.dart';
import '../widgets/category_breakdown_chart.dart';
import '../widgets/trend_bar_chart.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // Anchors the share sheet's popover to the Export button on iPad/Mac —
  // required there (unlike iPhone) or UIActivityViewController falls back
  // to an arbitrary/default position instead of appearing next to the
  // button that was actually tapped.
  final _exportButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsProvider>().load();
      context.read<CategoryProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          Consumer<ReportsProvider>(
            builder: (context, provider, _) => PopupMenuButton<String>(
              key: _exportButtonKey,
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export',
              enabled: provider.filteredExpenses.isNotEmpty,
              onSelected: (value) => _export(context, provider, value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
                PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
              ],
            ),
          ),
        ],
      ),
      body: Consumer<ReportsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.filteredExpenses.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: provider.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PeriodSegment(provider: provider),
                const SizedBox(height: 12),
                _PeriodNavigator(provider: provider),
                const SizedBox(height: 16),
                _FilterRow(provider: provider),
                const SizedBox(height: 16),
                _SummaryRow(provider: provider),
                const SizedBox(height: 24),
                const _SectionHeader('Trend'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: TrendBarChart(buckets: provider.chartBuckets),
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionHeader('By Category'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: CategoryBreakdownChart(
                        breakdown: provider.categoryBreakdown),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeader('Transactions (${provider.filteredExpenses.length})'),
                const SizedBox(height: 12),
                if (provider.filteredExpenses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: EmptyState(
                      message: 'No transactions found',
                      icon: Icons.receipt_long_outlined,
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0;
                            i < provider.filteredExpenses.length;
                            i++)
                          _ReportTransactionTile(
                            expense: provider.filteredExpenses[i],
                            showBottomBorder:
                                i < provider.filteredExpenses.length - 1,
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _export(
      BuildContext context, ReportsProvider provider, String format) async {
    final scaffold = ScaffoldMessenger.of(context);
    final box =
        _exportButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null
        ? (box.localToGlobal(Offset.zero) & box.size)
        : null;
    try {
      if (format == 'csv') {
        await ReportExporter.exportCsv(
          expenses: provider.filteredExpenses,
          periodLabel: provider.periodLabel,
          sharePositionOrigin: origin,
        );
      } else {
        await ReportExporter.exportPdf(
          expenses: provider.filteredExpenses,
          periodLabel: provider.periodLabel,
          totalIncome: provider.totalIncome,
          totalExpense: provider.totalExpense,
          sharePositionOrigin: origin,
        );
      }
    } catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    // headline-sm: 20px/600, on-surface — matches the section-title
    // convention used on Dashboard/Budgets (e.g. Budgets' "Categories").
    return Text(title,
        style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary));
  }
}

// Pill-toggle segmented control — same visual language as Dashboard's and
// Budgets' period switchers, extended to 3 segments for Daily/Weekly/
// Monthly. Purely a restyle of the old Material `SegmentedButton`: still
// calls the same `provider.period`/`setPeriod()` API, same 3 values.
class _PeriodSegment extends StatelessWidget {
  const _PeriodSegment({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, ReportPeriod value) {
      final active = provider.period == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => provider.setPeriod(value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
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
                color:
                    active ? AppTheme.textPrimary : AppTheme.onSurfaceVariant,
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          segment('Daily', ReportPeriod.daily),
          segment('Weekly', ReportPeriod.weekly),
          segment('Monthly', ReportPeriod.monthly),
        ],
      ),
    );
  }
}

// Restyled to match Budgets' `_MonthNavigator`: muted chevrons + a
// centered uppercase tracked label, instead of the old plain bold text.
class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: provider.previousPeriod,
          icon: const Icon(Icons.chevron_left),
          color: AppTheme.textSecondary,
        ),
        Text(
          provider.periodLabel.toUpperCase(),
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 1.2,
              color: AppTheme.textSecondary),
        ),
        IconButton(
          onPressed: provider.nextPeriod,
          icon: const Icon(Icons.chevron_right),
          color: AppTheme.textSecondary,
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Consumer<CategoryProvider>(
            builder: (context, catProvider, _) {
              return DropdownButtonFormField<Category?>(
                value: provider.categoryFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  ...catProvider.categories.map(
                    (c) => DropdownMenuItem(value: c, child: Text(c.name)),
                  ),
                ],
                onChanged: provider.setCategoryFilter,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<TransactionType?>(
            value: provider.typeFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Type',
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(
                  value: TransactionType.income, child: Text('Income')),
              DropdownMenuItem(
                  value: TransactionType.expense, child: Text('Expense')),
            ],
            onChanged: provider.setTypeFilter,
          ),
        ),
      ],
    );
  }
}

// Icon-circle stat cards matching Dashboard's `_IncomeExpenseRow` treatment,
// extended to 3 columns (Income/Expense/Net) — same values as the old
// `_StatCard` row, each amount still tinted by its own semantic color.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    Widget stat(IconData icon, Color color, String label, double amount) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppTheme.outlineVariant.withOpacity(0.3)),
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
                decoration:
                    BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: color),
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
                CurrencyFormatter.formatCompact(amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        stat(Icons.arrow_downward, AppTheme.incomeColor, 'Income',
            provider.totalIncome),
        const SizedBox(width: 12),
        stat(Icons.arrow_upward, AppTheme.expenseColor, 'Expense',
            provider.totalExpense),
        const SizedBox(width: 12),
        stat(Icons.account_balance_wallet_outlined, AppTheme.primaryColor,
            'Net', provider.net),
      ],
    );
  }
}

// Flat bordered row inside a single shared card (ExpenseListScreen's
// grouped-card pattern), rather than one Card per transaction. Only income
// is tinted green — regular expenses stay on-surface, matching ExpenseTile.
class _ReportTransactionTile extends StatelessWidget {
  const _ReportTransactionTile({
    required this.expense,
    this.showBottomBorder = true,
  });

  final Expense expense;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    final isExpense = expense.isExpense;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: showBottomBorder
          ? BoxDecoration(
              border: Border(
                bottom:
                    BorderSide(color: AppTheme.outlineVariant.withOpacity(0.3)),
              ),
            )
          : null,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: expense.category.color.withOpacity(0.1),
            child: Icon(expense.category.icon,
                color: expense.category.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                Text(
                  '${expense.category.name} • ${DateFormatter.toDisplay(expense.date)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'} ${CurrencyFormatter.format(expense.amount)}',
            style: TextStyle(
              color: isExpense ? AppTheme.textPrimary : AppTheme.incomeColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
