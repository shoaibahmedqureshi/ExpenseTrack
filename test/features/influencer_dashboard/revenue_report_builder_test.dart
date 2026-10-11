import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/influencer_dashboard/domain/currency_totals.dart';
import 'package:outlay/features/influencer_dashboard/domain/entities/influencer_revenue.dart';
import 'package:outlay/features/influencer_dashboard/domain/revenue_report_builder.dart';

InfluencerRevenue rev(
        String code, double amount, String currency, DateTime when,
        {String plan = 'pro'}) =>
    InfluencerRevenue(
      id: '${code}_${amount}_$when',
      userId: 'u',
      influencerCode: code,
      subscriptionPlan: plan,
      revenueAmount: amount,
      currency: currency,
      transactionDate: when,
      createdAt: when,
    );

void main() {
  final now = DateTime(2026, 10, 12, 15);

  group('currency totals', () {
    test('sums each currency separately and ignores case and blanks', () {
      final t = sumByCurrency([
        rev('a', 10, 'usd', now),
        rev('a', 5, 'USD', now),
        rev('a', 100, 'PKR', now),
        rev('a', 1, '', now),
      ]);
      expect(t, {'USD': 15.0, 'PKR': 100.0, '?': 1.0});
    });

    test('formats one sorted line per currency, or a zero fallback', () {
      expect(formatTotals({'USD': 1.5, 'PKR': 20}), ['PKR 20.00', 'USD 1.50']);
      expect(formatTotals({}), ['PKR 0.00']);
      expect(formatTotals({}, fallbackCurrency: 'USD'), ['USD 0.00']);
    });

    test('averages divide by that currency\'s own count', () {
      expect(averageByCurrency({'USD': 30, 'PKR': 100}, {'USD': 3, 'PKR': 4}),
          {'USD': 10.0, 'PKR': 25.0});
      expect(averageByCurrency({'USD': 30}, {}), isEmpty);
    });
  });

  group('buildRevenueReport', () {
    final revenues = [
      rev('A', 10, 'USD', DateTime(2026, 10, 3)),
      rev('A', 20, 'USD', DateTime(2026, 9, 3)),
      rev('B', 500, 'PKR', DateTime(2026, 10, 5)),
      rev('B', 700, 'PKR', DateTime(2025, 12, 31)),
    ];
    final r = buildRevenueReport(revenues, now);

    test('totals and conversions per currency', () {
      expect(r.totalsByCurrency, {'USD': 30.0, 'PKR': 1200.0});
      expect(r.conversionsByCurrency, {'USD': 2, 'PKR': 2});
      expect(r.totalConversions, 4);
    });

    test('this month and this year are calendar periods per currency', () {
      expect(r.monthlyByCurrency, {'USD': 10.0, 'PKR': 500.0});
      expect(r.yearlyByCurrency, {'USD': 30.0, 'PKR': 500.0});
    });

    test('monthly trends are per currency and in date order', () {
      expect(r.monthlyTrends.map((m) => m.month.month).toList(), [12, 9, 10]);
      expect(
          r.monthlyTrends.last.revenueByCurrency, {'USD': 10.0, 'PKR': 500.0});
    });

    test('an empty list gives an empty report, not an error', () {
      final e = buildRevenueReport([], now);
      expect(e.totalsByCurrency, isEmpty);
      expect(e.totalConversions, 0);
      expect(e.revenueByCode, isEmpty);
    });
  });

  group('groupRevenueByCode', () {
    test('orders by conversions, then code, and splits currencies', () {
      final codes = groupRevenueByCode([
        rev('B', 1, 'USD', now),
        rev('A', 1, 'USD', now),
        rev('C', 1, 'USD', now),
        rev('C', 50, 'PKR', now),
      ]);
      expect(codes.map((c) => c.code).toList(), ['C', 'A', 'B']);
      expect(codes.first.totalsByCurrency, {'USD': 1.0, 'PKR': 50.0});
      expect(codes.first.conversions, 2);
    });

    test('first and last conversion do not depend on input order', () {
      final c = groupRevenueByCode([
        rev('A', 1, 'USD', DateTime(2026, 5, 1)),
        rev('A', 1, 'USD', DateTime(2026, 9, 1)),
        rev('A', 1, 'USD', DateTime(2026, 7, 1)),
      ]).single;
      expect(c.firstConversion, DateTime(2026, 5, 1));
      expect(c.lastConversion, DateTime(2026, 9, 1));
    });
  });

  group('revenueReportCsv', () {
    test('one row per code and currency, quoted when needed', () {
      final report = buildRevenueReport([
        rev('SARA20', 10, 'USD', now),
        rev('SARA20', 90, 'USD', now),
        rev('SARA20', 400, 'PKR', now),
        rev('A,"B"', 5, 'USD', now),
      ], now);
      final lines = revenueReportCsv(report).trim().split('\n');
      expect(lines.first,
          'Influencer Code,Currency,Total Revenue,Conversions,Avg Revenue');
      expect(lines, contains('SARA20,PKR,400.00,1,400.00'));
      expect(lines, contains('SARA20,USD,100.00,2,50.00'));
      expect(lines, contains('"A,""B""",USD,5.00,1,5.00'));
    });
  });
}
