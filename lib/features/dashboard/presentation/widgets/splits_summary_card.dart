import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../expense_split/domain/split_models.dart';
import '../../../expense_split/presentation/providers/expense_split_provider.dart';

/// Shared-expense balances at a glance, across the family and every group: what you owe and what you're owed,
/// with the biggest balances listed underneath. Hidden until something has been split or paid.
class SplitsSummaryCard extends StatelessWidget {
  const SplitsSummaryCard({super.key, required this.onTap});

  /// Opens the Splits tab.
  final VoidCallback onTap;

  static const _maxRows = 3;

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseSplitProvider>(builder: (context, sp, _) {
      if (!sp.hasOverviewActivity) return const SizedBox.shrink();

      final totals = sp.overviewTotals;
      final open = sp.overview.where((b) => b.netCents != 0).toList()
        ..sort((a, b) => b.netCents.abs().compareTo(a.netCents.abs()));
      final settled = open.isEmpty;

      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.groups_2_outlined, size: 18, color: AppTheme.textSecondary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Shared expenses',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                  ),
                  Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                ]),
                const SizedBox(height: 12),
                if (settled)
                  const Text('You\'re all settled up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))
                else
                  Row(children: [
                    Expanded(child: _figure('You owe', totals.owe, Colors.red.shade700)),
                    const SizedBox(width: 12),
                    Expanded(child: _figure('You\'re owed', totals.owed, Colors.green.shade700)),
                  ]),
                if (!settled) ...[
                  const SizedBox(height: 8),
                  for (final b in open.take(_maxRows)) _row(context, sp, b),
                  if (open.length > _maxRows)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('+ ${open.length - _maxRows} more',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ),
                ],
              ]),
            ),
          ),
        ),
      );
    });
  }

  Widget _row(BuildContext context, ExpenseSplitProvider sp, LedgerBalance b) {
    final owed = b.netCents > 0;
    final label = b.ledger.kind == LedgerKind.family ? 'Family' : b.ledger.name;
    return InkWell(
      onTap: () {
        // Land on the ledger that was tapped, not whichever one was open last.
        sp.load(b.ledger);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Text(
            owed
                ? 'owed ${CurrencyFormatter.format(b.netCents / 100)}'
                : 'you owe ${CurrencyFormatter.format(-b.netCents / 100)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: owed ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _figure(String label, int cents, Color color) {
    final zero = cents == 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(CurrencyFormatter.format(cents / 100),
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: zero ? AppTheme.textSecondary : color)),
    ]);
  }
}
