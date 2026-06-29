import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../budgets/presentation/screens/budgets_screen.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../../../expenses/presentation/screens/expense_list_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../receipt_scanner/presentation/widgets/scan_fab.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            tooltip: 'Budgets',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Reports',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportsScreen()),
            ),
          ),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final initial = (auth.profile?.name?.isNotEmpty == true
                      ? auth.profile!.name![0]
                      : auth.profile?.email[0] ?? '?')
                  .toUpperCase();
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.white.withOpacity(.25),
                    child: Text(initial,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 14)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: provider.loadAll,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _BalanceHeader(provider: provider),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        label: 'Income',
                        amount: provider.totalIncome,
                        color: AppTheme.incomeColor,
                        icon: Icons.arrow_downward,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        label: 'Expenses',
                        amount: provider.totalExpense,
                        color: AppTheme.expenseColor,
                        icon: Icons.arrow_upward,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Transactions',
                        style: Theme.of(context).textTheme.titleMedium),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExpenseListScreen(),
                        ),
                      ),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                ...provider.expenses.take(5).map(
                      (e) => _TransactionTile(expense: e),
                    ),
                // Bottom padding so last tile isn't hidden behind the FAB.
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: const ScanFab(),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.provider});

  final ExpenseProvider provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.primaryColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('Total Balance',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(
              CurrencyFormatter.format(provider.balance),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.expense});

  final dynamic expense;

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
        subtitle: Text(expense.category.name),
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
