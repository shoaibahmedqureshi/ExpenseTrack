import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../receipt_scanner/presentation/widgets/scan_fab.dart';
import '../providers/expense_provider.dart';
import '../widgets/expense_tile.dart';
import 'add_expense_screen.dart';

class ExpenseListScreen extends StatelessWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Transactions')),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          return LoadingOverlay(
            isLoading: provider.isLoading,
            child: provider.expenses.isEmpty
                ? const EmptyState(
                    message: 'No transactions yet.\nScan a receipt to start.',
                    icon: Icons.document_scanner_outlined,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: provider.expenses.length,
                    itemBuilder: (context, index) {
                      final expense = provider.expenses[index];
                      return ExpenseTile(
                        expense: expense,
                        onDelete: () => provider.remove(expense.id!),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddExpenseScreen(expense: expense),
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
      floatingActionButton: const ScanFab(),
    );
  }
}
