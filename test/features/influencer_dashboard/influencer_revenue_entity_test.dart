import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/influencer_dashboard/domain/entities/influencer_revenue.dart';
import 'package:outlay/features/influencer_dashboard/domain/entities/revenue_report.dart';

void main() {
  group('InfluencerRevenue Entity', () {
    test('creates instance with all fields', () {
      final date = DateTime(2026, 9, 28);
      final entity = InfluencerRevenue(
        id: 'rev_123',
        userId: 'user_123',
        familyId: 'fam_123',
        influencerCode: 'CODE001',
        subscriptionPlan: 'proMonthly',
        revenueAmount: 999.00,
        currency: 'PKR',
        transactionDate: date,
        createdAt: date,
      );

      expect(entity.id, 'rev_123');
      expect(entity.userId, 'user_123');
      expect(entity.familyId, 'fam_123');
      expect(entity.influencerCode, 'CODE001');
      expect(entity.subscriptionPlan, 'proMonthly');
      expect(entity.revenueAmount, 999.00);
      expect(entity.currency, 'PKR');
    });

    test('copyWith updates fields correctly', () {
      final date = DateTime(2026, 9, 28);
      final original = InfluencerRevenue(
        id: 'rev_123',
        userId: 'user_123',
        influencerCode: 'CODE001',
        subscriptionPlan: 'proMonthly',
        revenueAmount: 999.00,
        currency: 'PKR',
        transactionDate: date,
        createdAt: date,
      );

      final updated = original.copyWith(
        revenueAmount: 1500.00,
        influencerCode: 'CODE002',
      );

      expect(updated.revenueAmount, 1500.00);
      expect(updated.influencerCode, 'CODE002');
      expect(updated.userId, original.userId); // Unchanged
      expect(updated.id, original.id); // Unchanged
    });

    test('toJson creates valid map', () {
      final date = DateTime(2026, 9, 28);
      final entity = InfluencerRevenue(
        id: 'rev_123',
        userId: 'user_123',
        influencerCode: 'CODE001',
        subscriptionPlan: 'proMonthly',
        revenueAmount: 999.00,
        currency: 'PKR',
        transactionDate: date,
        createdAt: date,
      );

      final json = entity.toJson();

      expect(json['id'], 'rev_123');
      expect(json['user_id'], 'user_123');
      expect(json['influencer_code'], 'CODE001');
      expect(json['revenue_amount'], 999.00);
      expect(json.containsKey('transaction_date'), true);
    });

    test('fromJson creates entity from map', () {
      final date = DateTime(2026, 9, 28);
      final json = {
        'id': 'rev_123',
        'user_id': 'user_123',
        'family_id': null,
        'influencer_code': 'CODE001',
        'subscription_plan': 'proMonthly',
        'revenue_amount': 999.00,
        'currency': 'PKR',
        'transaction_date': date.toIso8601String(),
        'created_at': date.toIso8601String(),
      };

      final entity = InfluencerRevenue.fromJson(json);

      expect(entity.id, 'rev_123');
      expect(entity.userId, 'user_123');
      expect(entity.influencerCode, 'CODE001');
      expect(entity.revenueAmount, 999.00);
    });

    test('familyId is optional', () {
      final date = DateTime(2026, 9, 28);
      final entity = InfluencerRevenue(
        id: 'rev_123',
        userId: 'user_123',
        influencerCode: 'CODE001',
        subscriptionPlan: 'proMonthly',
        revenueAmount: 999.00,
        currency: 'PKR',
        transactionDate: date,
        createdAt: date,
      );

      expect(entity.familyId, isNull);
    });
  });

  group('CodeRevenue Entity', () {
    CodeRevenue sample() => CodeRevenue(
          code: 'CODE001',
          totalsByCurrency: {'PKR': 5000.00, 'USD': 30.00},
          conversionsByCurrency: {'PKR': 5, 'USD': 3},
          subscriptionPlans: ['proMonthly', 'proAnnual'],
          firstConversion: DateTime(2026, 8, 28),
          lastConversion: DateTime(2026, 9, 28),
        );

    test('keeps each currency separate', () {
      final code = sample();
      expect(code.code, 'CODE001');
      expect(code.totalsByCurrency, {'PKR': 5000.00, 'USD': 30.00});
      expect(code.conversions, 8);
    });

    test('averages per currency, never across currencies', () {
      expect(sample().averageByCurrencyTotals, {'PKR': 1000.00, 'USD': 10.00});
    });

    test('toJson and fromJson round trip', () {
      final restored = CodeRevenue.fromJson(sample().toJson());
      expect(restored.code, 'CODE001');
      expect(restored.totalsByCurrency, {'PKR': 5000.00, 'USD': 30.00});
      expect(restored.conversionsByCurrency, {'PKR': 5, 'USD': 3});
      expect(restored.conversions, 8);
    });
  });

  group('MonthlyTrend Entity', () {
    test('toJson and fromJson round trip', () {
      final original = MonthlyTrend(
        month: DateTime(2026, 9),
        revenueByCurrency: {'PKR': 5000.00, 'USD': 12.5},
        conversions: 5,
      );
      final restored = MonthlyTrend.fromJson(original.toJson());
      expect(restored.month.year, 2026);
      expect(restored.month.month, 9);
      expect(restored.revenueByCurrency, {'PKR': 5000.00, 'USD': 12.5});
      expect(restored.conversions, 5);
    });
  });

  group('RevenueReport Entity', () {
    RevenueReport report({
      Map<String, double> totals = const {},
      Map<String, int> counts = const {},
    }) =>
        RevenueReport(
          totalsByCurrency: totals,
          conversionsByCurrency: counts,
          monthlyByCurrency: const {},
          yearlyByCurrency: const {},
          revenueByCode: [],
          monthlyTrends: [],
          generatedAt: DateTime(2026, 10, 12),
        );

    test('averages per conversion in each currency', () {
      final r = report(
          totals: {'PKR': 5000, 'USD': 30}, counts: {'PKR': 5, 'USD': 3});
      expect(r.averageByCurrencyTotals, {'PKR': 1000.0, 'USD': 10.0});
      expect(r.totalConversions, 8);
    });

    test('no conversions means no averages', () {
      final r = report();
      expect(r.averageByCurrencyTotals, isEmpty);
      expect(r.totalConversions, 0);
    });

    test('stores generated timestamp', () {
      expect(report().generatedAt, DateTime(2026, 10, 12));
    });
  });
}
