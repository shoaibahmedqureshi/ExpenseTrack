import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../providers/reports_provider.dart';

class TrendBarChart extends StatelessWidget {
  const TrendBarChart({super.key, required this.buckets});

  final List<ChartBucket> buckets;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty || buckets.every((b) => b.income == 0 && b.expense == 0)) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('No data for this period')),
      );
    }

    final maxY = buckets
        .map((b) => b.income > b.expense ? b.income : b.expense)
        .fold(0.0, (a, b) => a > b ? a : b);

    final labelEvery = buckets.length > 12 ? (buckets.length / 6).ceil() : 1;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY <= 0 ? 1 : maxY * 1.2,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= buckets.length) return const SizedBox();
                  if (i % labelEvery != 0) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(buckets[i].label,
                        style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final bucket = buckets[groupIndex];
                final isExpense = rodIndex == 1;
                return BarTooltipItem(
                  '${bucket.label}\n${CurrencyFormatter.format(isExpense ? bucket.expense : bucket.income)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          barGroups: List.generate(buckets.length, (i) {
            final b = buckets[i];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: b.income,
                  color: AppTheme.incomeColor,
                  width: 6,
                  borderRadius: BorderRadius.circular(2),
                ),
                BarChartRodData(
                  toY: b.expense,
                  color: AppTheme.expenseColor,
                  width: 6,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
              barsSpace: 3,
            );
          }),
        ),
      ),
    );
  }
}
