import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../expense_split/domain/split_calculator.dart';
import '../../../expense_split/presentation/member_names.dart';
import '../../../expense_split/presentation/providers/expense_split_provider.dart';
import '../../../family_accounts/presentation/providers/family_provider.dart';

/// Shared-expense balances at a glance: what you owe and what you're owed.
/// Hidden until the family has at least one split or payment.
class SplitsSummaryCard extends StatelessWidget {
  const SplitsSummaryCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final family = context.watch<FamilyProvider>();
    final familyId = family.currentFamily == null ? null : int.tryParse(family.currentFamily!.id);
    if (familyId == null) return const SizedBox.shrink();

    return Consumer<ExpenseSplitProvider>(builder: (context, sp, _) {
      if (sp.familyId != familyId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.read<ExpenseSplitProvider>().ensureLoaded(familyId);
        });
        return const SizedBox.shrink();
      }
      if (sp.splits.isEmpty && sp.settlements.isEmpty) return const SizedBox.shrink();

      final me = family.getCurrentUserId();
      final names = MemberNames(family.familyMembers, me);
      final debts = sp.debts;
      final totals = SplitCalculator.myTotals(debts, me);
      final mine = debts.where((d) => d.from == me || d.to == me).take(2).toList();
      final settled = totals.owe == 0 && totals.owed == 0;

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
                Row(children: const [
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
                  const Text('You\'re all settled up',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))
                else
                  Row(children: [
                    Expanded(child: _figure('You owe', totals.owe, Colors.red.shade700)),
                    const SizedBox(width: 12),
                    Expanded(child: _figure('You\'re owed', totals.owed, Colors.green.shade700)),
                  ]),
                if (!settled && mine.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final d in mine)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        d.from == me
                            ? 'You owe ${names.of(d.to)} ${CurrencyFormatter.format(d.cents / 100)}'
                            : '${names.of(d.from)} owes you ${CurrencyFormatter.format(d.cents / 100)}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                ],
              ]),
            ),
          ),
        ),
      );
    });
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
