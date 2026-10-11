import 'currency_totals.dart';
import 'entities/influencer_revenue.dart';
import 'entities/revenue_report.dart';

/// Builds the dashboard report. All figures are per currency, and "this month" / "this year"
/// are calendar periods in the user's local time (stored dates are UTC).
RevenueReport buildRevenueReport(
    List<InfluencerRevenue> revenues, DateTime now) {
  bool inMonth(InfluencerRevenue r) {
    final d = r.transactionDate.toLocal();
    return d.year == now.year && d.month == now.month;
  }

  bool inYear(InfluencerRevenue r) =>
      r.transactionDate.toLocal().year == now.year;

  return RevenueReport(
    totalsByCurrency: sumByCurrency(revenues),
    conversionsByCurrency: countByCurrency(revenues),
    monthlyByCurrency: sumByCurrency(revenues.where(inMonth)),
    yearlyByCurrency: sumByCurrency(revenues.where(inYear)),
    revenueByCode: groupRevenueByCode(revenues),
    monthlyTrends: monthlyTrendsOf(revenues),
    generatedAt: now,
  );
}

/// One entry per influencer code, busiest first. Codes are ordered by number of conversions,
/// because revenue in different currencies cannot be compared.
List<CodeRevenue> groupRevenueByCode(List<InfluencerRevenue> revenues) {
  final grouped = <String, List<InfluencerRevenue>>{};
  for (final r in revenues) {
    grouped.putIfAbsent(r.influencerCode, () => []).add(r);
  }
  final list = grouped.entries.map((e) {
    final items = e.value;
    final dates = items.map((r) => r.transactionDate).toList()..sort();
    return CodeRevenue(
      code: e.key,
      totalsByCurrency: sumByCurrency(items),
      conversionsByCurrency: countByCurrency(items),
      subscriptionPlans: items.map((r) => r.subscriptionPlan).toSet().toList(),
      firstConversion: dates.first,
      lastConversion: dates.last,
    );
  }).toList();
  list.sort((a, b) {
    final byCount = b.conversions.compareTo(a.conversions);
    return byCount != 0 ? byCount : a.code.compareTo(b.code);
  });
  return list;
}

List<MonthlyTrend> monthlyTrendsOf(List<InfluencerRevenue> revenues) {
  final grouped = <DateTime, List<InfluencerRevenue>>{};
  for (final r in revenues) {
    final d = r.transactionDate.toLocal();
    grouped.putIfAbsent(DateTime(d.year, d.month), () => []).add(r);
  }
  return grouped.entries
      .map((e) => MonthlyTrend(
            month: e.key,
            revenueByCurrency: sumByCurrency(e.value),
            conversions: e.value.length,
          ))
      .toList()
    ..sort((a, b) => a.month.compareTo(b.month));
}

/// CSV with one row per code and currency.
String revenueReportCsv(RevenueReport report) {
  final b = StringBuffer(
      'Influencer Code,Currency,Total Revenue,Conversions,Avg Revenue\n');
  for (final code in report.revenueByCode) {
    final currencies = code.totalsByCurrency.keys.toList()..sort();
    for (final c in currencies) {
      final total = code.totalsByCurrency[c]!;
      final n = code.conversionsByCurrency[c] ?? 0;
      b.writeln(
          '${_csv(code.code)},$c,${total.toStringAsFixed(2)},$n,${(n > 0 ? total / n : 0).toStringAsFixed(2)}');
    }
  }
  return b.toString();
}

String _csv(String v) =>
    v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
