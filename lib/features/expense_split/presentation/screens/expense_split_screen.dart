import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../family_accounts/presentation/providers/family_provider.dart';
import '../providers/expense_split_provider.dart';

class ExpenseSplitScreen extends StatefulWidget {
  const ExpenseSplitScreen({Key? key}) : super(key: key);

  @override
  State<ExpenseSplitScreen> createState() => _ExpenseSplitScreenState();
}

class _ExpenseSplitScreenState extends State<ExpenseSplitScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final familyProvider = Provider.of<FamilyProvider>(context, listen: false);
    final splitProvider = Provider.of<ExpenseSplitProvider>(context, listen: false);
    
    if (familyProvider.currentFamily != null) {
      splitProvider.loadFamilySplits(familyProvider.currentFamily!.id.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyProvider = Provider.of<FamilyProvider>(context);
    
    if (familyProvider.currentFamily == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expense Split')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.group_off, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text('No family group selected'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Split'),
        elevation: 0,
      ),
      body: Consumer<ExpenseSplitProvider>(
        builder: (context, splitProvider, _) {
          if (splitProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (splitProvider.pendingSettlements.isEmpty && splitProvider.splits.isEmpty) {
            return _buildEmptyState();
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                if (splitProvider.pendingSettlements.isNotEmpty) ...[
                  _buildPendingSettlementsSection(context, splitProvider),
                  const SizedBox(height: 24),
                ],
                if (splitProvider.splits.isNotEmpty) ...[
                  _buildExpenseSplitsSection(context, splitProvider),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSplitDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No expenses to split',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new expense split to get started',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSettlementsSection(
    BuildContext context,
    ExpenseSplitProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Pending Settlements',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ...provider.pendingSettlements.map((settlement) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text('${settlement.fromMemberId} owes ${settlement.toMemberId}'),
              subtitle: Text('PKR ${settlement.amount.toStringAsFixed(2)}'),
              trailing: ElevatedButton(
                onPressed: () => _settlePayment(context, provider, settlement),
                child: const Text('Settle'),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildExpenseSplitsSection(
    BuildContext context,
    ExpenseSplitProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Expense Splits (${provider.splits.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ...provider.splits.map((split) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text('Total: PKR ${split.totalAmount.toStringAsFixed(2)}'),
              subtitle: Text('${split.splitAmounts.length} people • ${split.currency}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showSplitDetails(context, split),
            ),
          );
        }).toList(),
      ],
    );
  }

  void _showCreateSplitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Expense Split'),
        content: const Text('Split creation coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSplitDetails(BuildContext context, dynamic split) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Split Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: PKR ${split.totalAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            Text('Split amounts:', style: Theme.of(context).textTheme.labelLarge),
            ...(split.splitAmounts.entries.map((e) => Text('${e.key}: PKR ${e.value.toStringAsFixed(2)}')).toList()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _settlePayment(BuildContext context, ExpenseSplitProvider provider, dynamic settlement) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Settle Payment?'),
        content: Text('Mark PKR ${settlement.amount.toStringAsFixed(2)} as paid?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.settlePayment(settlement);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment settled')),
              );
            },
            child: const Text('Settle'),
          ),
        ],
      ),
    );
  }
}
