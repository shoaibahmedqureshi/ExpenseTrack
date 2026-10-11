import 'entities/influencer_revenue.dart';

/// Amounts per ISO currency code. Amounts in different currencies are never added together.
typedef CurrencyTotals = Map<String, double>;

String normalizeCurrency(String? c) {
  final v = (c ?? '').trim().toUpperCase();
  return v.isEmpty ? '?' : v;
}

CurrencyTotals sumByCurrency(Iterable<InfluencerRevenue> items) {
  final out = <String, double>{};
  for (final r in items) {
    final c = normalizeCurrency(r.currency);
    out[c] = (out[c] ?? 0) + r.revenueAmount;
  }
  return out;
}

Map<String, int> countByCurrency(Iterable<InfluencerRevenue> items) {
  final out = <String, int>{};
  for (final r in items) {
    final c = normalizeCurrency(r.currency);
    out[c] = (out[c] ?? 0) + 1;
  }
  return out;
}

String formatMoney(double amount, String currency) =>
    '$currency ${amount.toStringAsFixed(2)}';

/// One "CODE 12.34" line per currency, sorted by code. Empty totals read as zero in
/// [fallbackCurrency] so a card is never blank.
List<String> formatTotals(CurrencyTotals totals,
    {String fallbackCurrency = 'PKR'}) {
  if (totals.isEmpty) return [formatMoney(0, fallbackCurrency)];
  final codes = totals.keys.toList()..sort();
  return [for (final c in codes) formatMoney(totals[c]!, c)];
}

/// Average per conversion in each currency (total / that currency's conversions).
CurrencyTotals averageByCurrency(
        CurrencyTotals totals, Map<String, int> counts) =>
    {
      for (final e in totals.entries)
        if ((counts[e.key] ?? 0) > 0) e.key: e.value / counts[e.key]!,
    };
