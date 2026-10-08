import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../household/domain/household_calculator.dart';
import '../../../household/presentation/providers/household_provider.dart';

/// The family's monthly budget at a glance. Shown only to someone in a family, and only once there is something to
/// show: a budget has been set, or at least one person shares their monthly totals.
class HouseholdSummaryCard extends StatelessWidget {
  const HouseholdSummaryCard({super.key, required this.onTap});

  /// Opens the household budget screen.
  final VoidCallback onTap;

  String _money(int cents) => CurrencyFormatter.format(cents / 100);

  @override
  Widget build(BuildContext context) {
    return Consumer<HouseholdProvider>(builder: (context, p, _) {
      final o = p.current;
      if (p.familyId == null || o.members.isEmpty) return const SizedBox.shrink();

      final status = HouseholdCalculator.overall(o);
      final sharing = HouseholdCalculator.sharingCount(o);
      if (status == null && sharing == 0) return const SizedBox.shrink();

      final spent = HouseholdCalculator.totalCents(o);
      final over = status?.isOver ?? false;
      final color = over ? Colors.red.shade700 : AppTheme.primaryColor;
      final iAmSharing = p.isSharing;

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
                Row(children: [
                  const Icon(Icons.pie_chart_outline, size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Household budget · ${DateFormat.MMM().format(o.month)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                ]),
                const SizedBox(height: 12),
                if (status != null) ...[
                  Text(
                    over ? '${_money(-status.remainingCents)} over budget' : '${_money(status.remainingCents)} left',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                        value: status.fraction, minHeight: 8, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(color)),
                  ),
                  const SizedBox(height: 6),
                  Text('${_money(spent)} of ${_money(status.budgetCents)} spent',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ] else ...[
                  Text(_money(spent), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(p.isOwner ? 'spent so far. Tap to set a budget.' : 'spent so far this month',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
                const SizedBox(height: 8),
                Text(
                  '$sharing of ${o.members.length} sharing'
                  '${iAmSharing ? '' : ' · tap to share yours'}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ]),
            ),
          ),
        ),
      );
    });
  }
}
