import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
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
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: provider.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PeriodSelector(provider: provider),
                const SizedBox(height: 12),
                _PeriodNavigator(provider: provider),
                const SizedBox(height: 16),
                _FilterRow(provider: provider),
                const SizedBox(height: 16),
                _SummaryRow(provider: provider),
                const SizedBox(height: 24),
                Text('Trend', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TrendBarChart(buckets: provider.chartBuckets),
                  ),
                ),
                const SizedBox(height: 24),
                Text('By Category', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CategoryBreakdownChart(
                        breakdown: provider.categoryBreakdown),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Transactions (${provider.filteredExpenses.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (provider.filteredExpenses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No transactions found')),
                  )
                else
                  ...provider.filteredExpenses.map(
                    (e) => _ReportTransactionTile(expense: e),
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
    try {
      if (format == 'csv') {
        await ReportExporter.exportCsv(
          expenses: provider.filteredExpenses,
          periodLabel: provider.periodLabel,
        );
      } else {
        await ReportExporter.exportPdf(
          expenses: provider.filteredExpenses,
          periodLabel: provider.periodLabel,
          totalIncome: provider.totalIncome,
          totalExpense: provider.totalExpense,
        );
      }
    } catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ReportPeriod>(
      segments: const [
        ButtonSegment(value: ReportPeriod.daily, label: Text('Daily')),
        ButtonSegment(value: ReportPeriod.weekly, label: Text('Weekly')),
        ButtonSegment(value: ReportPeriod.monthly, label: Text('Monthly')),
      ],
      selected: {provider.period},
      onSelectionChanged: (s) => provider.setPeriod(s.first),
    );
  }
}

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
        ),
        Text(
          provider.periodLabel,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        IconButton(
          onPressed: provider.nextPeriod,
          icon: const Icon(Icons.chevron_right),
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Income',
            amount: provider.totalIncome,
            color: AppTheme.incomeColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Expense',
            amount: provider.totalExpense,
            color: AppTheme.expenseColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Net',
            amount: provider.net,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }
}

class _ReportTransactionTile extends StatelessWidget {
  const _ReportTransactionTile({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final isExpense = expense.isExpense;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: expense.category.color.withOpacity(0.15),
          child: Icon(expense.category.icon, color: expense.category.color),
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
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.amount, required this.color});

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.formatCompact(amount),
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: color, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
