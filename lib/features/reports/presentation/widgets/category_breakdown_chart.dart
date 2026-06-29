import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../providers/reports_provider.dart';

class CategoryBreakdownChart extends StatelessWidget {
  const CategoryBreakdownChart({super.key, required this.breakdown});

  final List<CategoryTotal> breakdown;

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('No expenses for this period')),
      );
    }

    return Row(
      children: [
        SizedBox(
          height: 160,
          width: 160,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: breakdown
                  .map((c) => PieChartSectionData(
                        value: c.total,
                        color: c.category.color,
                        radius: 28,
                        showTitle: false,
                      ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: breakdown.take(6).map((c) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: c.category.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(c.category.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${(c.percent * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.formatCompact(c.total),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
