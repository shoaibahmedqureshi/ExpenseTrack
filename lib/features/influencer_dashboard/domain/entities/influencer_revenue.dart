class InfluencerRevenue {
  final String id;
  final String userId;
  final String? familyId;
  final String influencerCode;
  final String subscriptionPlan;
  final double revenueAmount;
  final String currency;
  final DateTime transactionDate;
  final DateTime createdAt;

  InfluencerRevenue({
    required this.id,
    required this.userId,
    this.familyId,
    required this.influencerCode,
    required this.subscriptionPlan,
    required this.revenueAmount,
    required this.currency,
    required this.transactionDate,
    required this.createdAt,
  });

  InfluencerRevenue copyWith({
    String? id,
    String? userId,
    String? familyId,
    String? influencerCode,
    String? subscriptionPlan,
    double? revenueAmount,
    String? currency,
    DateTime? transactionDate,
    DateTime? createdAt,
  }) {
    return InfluencerRevenue(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      familyId: familyId ?? this.familyId,
      influencerCode: influencerCode ?? this.influencerCode,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      revenueAmount: revenueAmount ?? this.revenueAmount,
      currency: currency ?? this.currency,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'family_id': familyId,
      'influencer_code': influencerCode,
      'subscription_plan': subscriptionPlan,
      'revenue_amount': revenueAmount,
      'currency': currency,
      'transaction_date': transactionDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory InfluencerRevenue.fromJson(Map<String, dynamic> json) {
    return InfluencerRevenue(
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
}
