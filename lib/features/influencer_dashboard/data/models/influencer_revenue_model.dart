import '../../domain/entities/influencer_revenue.dart';

class InfluencerRevenueModel extends InfluencerRevenue {
  InfluencerRevenueModel({
    required super.id,
    required super.userId,
    super.familyId,
    required super.influencerCode,
    required super.subscriptionPlan,
    required super.revenueAmount,
    required super.currency,
    required super.transactionDate,
    required super.createdAt,
  });

  factory InfluencerRevenueModel.fromJson(Map<String, dynamic> json) {
    return InfluencerRevenueModel(
      id: json['id'].toString(),
      userId: json['user_id'] as String,
      familyId: json['family_id']?.toString(),
      influencerCode: json['influencer_code'] as String,
      subscriptionPlan: json['subscription_plan'] as String,
      revenueAmount: (json['revenue_amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'PKR',
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  factory InfluencerRevenueModel.fromEntity(InfluencerRevenue entity) {
    return InfluencerRevenueModel(
      id: entity.id,
      userId: entity.userId,
      familyId: entity.familyId,
      influencerCode: entity.influencerCode,
      subscriptionPlan: entity.subscriptionPlan,
      revenueAmount: entity.revenueAmount,
      currency: entity.currency,
      transactionDate: entity.transactionDate,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'family_id': familyId,
      'influencer_code': influencerCode,
      'subscription_plan': subscriptionPlan,
      'revenue_amount': revenueAmount,
      'currency': currency,
      'transaction_date': transactionDate.toIso8601String(),
    };
  }
}
