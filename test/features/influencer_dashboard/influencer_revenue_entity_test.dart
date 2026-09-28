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
    test('creates instance with all fields', () {
      final firstDate = DateTime(2026, 8, 28);
      final lastDate = DateTime(2026, 9, 28);

      final code = CodeRevenue(
        code: 'CODE001',
        totalRevenue: 5000.00,
        conversions: 5,
        subscriptionPlans: ['proMonthly', 'proAnnual'],
        averageRevenue: 1000.00,
        firstConversion: firstDate,
        lastConversion: lastDate,
      );

      expect(code.code, 'CODE001');
      expect(code.totalRevenue, 5000.00);
      expect(code.conversions, 5);
      expect(code.averageRevenue, 1000.00);
    });

    test('toJson and fromJson round trip', () {
      final firstDate = DateTime(2026, 8, 28);
      final lastDate = DateTime(2026, 9, 28);

      final original = CodeRevenue(
        code: 'CODE001',
        totalRevenue: 5000.00,
        conversions: 5,
        subscriptionPlans: ['proMonthly'],
        averageRevenue: 1000.00,
        firstConversion: firstDate,
        lastConversion: lastDate,
      );

      final json = original.toJson();
      final restored = CodeRevenue.fromJson(json);

      expect(restored.code, original.code);
      expect(restored.totalRevenue, original.totalRevenue);
      expect(restored.conversions, original.conversions);
    });
  });

  group('MonthlyTrend Entity', () {
    test('creates instance correctly', () {
      final month = DateTime(2026, 9);

      final trend = MonthlyTrend(
        month: month,
        revenue: 5000.00,
        conversions: 5,
      );

      expect(trend.month, month);
      expect(trend.revenue, 5000.00);
      expect(trend.conversions, 5);
    });

    test('toJson and fromJson round trip', () {
      final month = DateTime(2026, 9);

      final original = MonthlyTrend(
        month: month,
        revenue: 5000.00,
        conversions: 5,
      );

      final json = original.toJson();
      final restored = MonthlyTrend.fromJson(json);

      expect(restored.month.year, original.month.year);
      expect(restored.month.month, original.month.month);
      expect(restored.revenue, original.revenue);
      expect(restored.conversions, original.conversions);
    });
  });

  group('RevenueReport Entity', () {
    test('calculates average revenue per conversion', () {
      final report = RevenueReport(
        totalRevenue: 5000.00,
        monthlyRevenue: 500.00,
        yearlyRevenue: 5000.00,
        totalConversions: 5,
        revenueByCode: [],
        monthlyTrends: [],
        generatedAt: DateTime.now(),
      );

      expect(report.averageRevenuePerConversion, 1000.00);
    });

    test('handles zero conversions for average', () {
      final report = RevenueReport(
        totalRevenue: 0,
        monthlyRevenue: 0,
        yearlyRevenue: 0,
        totalConversions: 0,
        revenueByCode: [],
        monthlyTrends: [],
        generatedAt: DateTime.now(),
      );

      expect(report.averageRevenuePerConversion, 0);
    });

    test('conversionRate equals totalConversions', () {
      final report = RevenueReport(
        totalRevenue: 5000.00,
        monthlyRevenue: 500.00,
        yearlyRevenue: 5000.00,
        totalConversions: 5,
        revenueByCode: [],
        monthlyTrends: [],
        generatedAt: DateTime.now(),
      );

      expect(report.conversionRate, 5.0);
    });

    test('stores generated timestamp', () {
      final now = DateTime.now();
      final report = RevenueReport(
        totalRevenue: 0,
        monthlyRevenue: 0,
        yearlyRevenue: 0,
        totalConversions: 0,
        revenueByCode: [],
        monthlyTrends: [],
        generatedAt: now,
      );

      expect(report.generatedAt, now);
    });
  });
}
