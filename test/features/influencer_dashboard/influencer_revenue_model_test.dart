import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/influencer_dashboard/domain/entities/influencer_revenue.dart';
import 'package:outlay/features/influencer_dashboard/data/models/influencer_revenue_model.dart';

void main() {
  group('InfluencerRevenueModel', () {
    const testId = 'rev_123';
    const testUserId = 'user_456';
    const testCode = 'INFLUENCER_001';
    const testPlan = 'proMonthly';
    const testAmount = 999.00;
    const testCurrency = 'PKR';
    final testDate = DateTime(2026, 9, 28);
    final testCreatedAt = DateTime(2026, 9, 28);

    test('fromJson creates model from map', () {
      final json = {
        'id': testId,
        'user_id': testUserId,
        'family_id': null,
        'influencer_code': testCode,
        'subscription_plan': testPlan,
        'revenue_amount': testAmount,
        'currency': testCurrency,
        'transaction_date': testDate.toIso8601String(),
        'created_at': testCreatedAt.toIso8601String(),
      };

      final model = InfluencerRevenueModel.fromJson(json);

      expect(model.id, testId);
      expect(model.userId, testUserId);
      expect(model.influencerCode, testCode);
      expect(model.subscriptionPlan, testPlan);
      expect(model.revenueAmount, testAmount);
      expect(model.currency, testCurrency);
    });

    test('fromJson handles missing family_id as null', () {
      final json = {
        'id': testId,
        'user_id': testUserId,
        'influencer_code': testCode,
        'subscription_plan': testPlan,
        'revenue_amount': testAmount,
        'currency': testCurrency,
        'transaction_date': testDate.toIso8601String(),
        'created_at': testCreatedAt.toIso8601String(),
      };

      final model = InfluencerRevenueModel.fromJson(json);

      expect(model.familyId, isNull);
    });

    test('toInsertJson converts model to insert format', () {
      final model = InfluencerRevenueModel(
        id: testId,
        userId: testUserId,
        familyId: null,
        influencerCode: testCode,
        subscriptionPlan: testPlan,
        revenueAmount: testAmount,
        currency: testCurrency,
        transactionDate: testDate,
        createdAt: testCreatedAt,
      );

      final json = model.toInsertJson();

      expect(json['user_id'], testUserId);
      expect(json['influencer_code'], testCode);
      expect(json['subscription_plan'], testPlan);
      expect(json['revenue_amount'], testAmount);
      expect(json['currency'], testCurrency);
      expect(json.containsKey('id'), false); // ID not included in insert
    });

    test('fromEntity creates model from entity', () {
      final entity = InfluencerRevenue(
        id: testId,
        userId: testUserId,
        influencerCode: testCode,
        subscriptionPlan: testPlan,
        revenueAmount: testAmount,
        currency: testCurrency,
        transactionDate: testDate,
        createdAt: testCreatedAt,
      );

      final model = InfluencerRevenueModel.fromEntity(entity);

      expect(model.id, testId);
      expect(model.userId, testUserId);
      expect(model.influencerCode, testCode);
      expect(model.revenueAmount, testAmount);
    });

    test('currency defaults to PKR when missing', () {
      final json = {
        'id': testId,
        'user_id': testUserId,
        'influencer_code': testCode,
        'subscription_plan': testPlan,
        'revenue_amount': testAmount,
        'transaction_date': testDate.toIso8601String(),
        'created_at': testCreatedAt.toIso8601String(),
      };

      final model = InfluencerRevenueModel.fromJson(json);

      expect(model.currency, 'PKR');
    });

    test('handles numeric revenue_amount as double', () {
      final json = {
        'id': testId,
        'user_id': testUserId,
        'influencer_code': testCode,
        'subscription_plan': testPlan,
        'revenue_amount': 1500, // int instead of double
        'currency': testCurrency,
        'transaction_date': testDate.toIso8601String(),
        'created_at': testCreatedAt.toIso8601String(),
      };

      final model = InfluencerRevenueModel.fromJson(json);

      expect(model.revenueAmount, 1500.0);
      expect(model.revenueAmount is double, true);
    });
  });
}
