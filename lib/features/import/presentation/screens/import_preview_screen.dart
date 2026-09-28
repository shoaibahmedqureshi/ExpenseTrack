import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/bank_statement.dart';

class ImportPreviewScreen extends StatelessWidget {
  final BankStatement bankStatement;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  const ImportPreviewScreen({
    super.key,
    required this.bankStatement,
    required this.onBack,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMMd();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bank & Account Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bankStatement.bankName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _infoRow('Account', bankStatement.accountNumber),
                  _infoRow(
                    'Period',
                    '${dateFormat.format(bankStatement.periodStart)} - ${dateFormat.format(bankStatement.periodEnd)}',
                  ),
                  _infoRow(
                    'Opening Balance',
                    CurrencyFormatter.format(bankStatement.openingBalance),
                  ),
                  _infoRow(
                    'Closing Balance',
                    CurrencyFormatter.format(bankStatement.closingBalance),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.incomeColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.info,
                            size: 18,
                            color: AppTheme.incomeColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${bankStatement.transactions.length} transactions ready to import',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Transactions List
          Text(
            'Transactions to Import',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: bankStatement.transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final txn = bankStatement.transactions[index];
              return _TransactionTile(transaction: txn);
            },
          ),
          const SizedBox(height: 32),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check),
                  label: const Text('Import All'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Transactions will be added to your expense list. You can edit or categorize them after import.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final BankStatementTransaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    final isExpense = transaction.isExpense;

    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isExpense ? AppTheme.expenseColor : AppTheme.incomeColor)
                .withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isExpense ? Icons.arrow_upward : Icons.arrow_downward,
            size: 20,
            color: isExpense ? AppTheme.expenseColor : AppTheme.incomeColor,
          ),
        ),
        title: Text(
          transaction.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          dateFormat.format(transaction.date),
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'} ${CurrencyFormatter.format(transaction.amount)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isExpense ? AppTheme.expenseColor : AppTheme.incomeColor,
          ),
        ),
      ),
    );
  }
}
