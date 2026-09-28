class RevenueReport {
  final double totalRevenue;
  final double monthlyRevenue;
  final double yearlyRevenue;
  final int totalConversions;
  final List<CodeRevenue> revenueByCode;
  final List<MonthlyTrend> monthlyTrends;
  final DateTime generatedAt;

  RevenueReport({
    required this.totalRevenue,
    required this.monthlyRevenue,
    required this.yearlyRevenue,
    required this.totalConversions,
    required this.revenueByCode,
    required this.monthlyTrends,
    required this.generatedAt,
  });

  double get averageRevenuePerConversion =>
      totalConversions > 0 ? totalRevenue / totalConversions : 0;

  double get conversionRate => totalConversions.toDouble();
}

class CodeRevenue {
  final String code;
  final double totalRevenue;
  final int conversions;
  final List<String> subscriptionPlans;
  final double averageRevenue;
  final DateTime firstConversion;
  final DateTime lastConversion;

  CodeRevenue({
    required this.code,
    required this.totalRevenue,
    required this.conversions,
    required this.subscriptionPlans,
    required this.averageRevenue,
    required this.firstConversion,
    required this.lastConversion,
  });

  factory CodeRevenue.fromJson(Map<String, dynamic> json) {
    return CodeRevenue(
      code: json['code'] as String,
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      conversions: json['conversions'] as int,
      subscriptionPlans:
          List<String>.from(json['subscriptionPlans'] as List),
      averageRevenue: (json['averageRevenue'] as num).toDouble(),
      firstConversion: DateTime.parse(json['firstConversion'] as String),
      lastConversion: DateTime.parse(json['lastConversion'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'totalRevenue': totalRevenue,
      'conversions': conversions,
      'subscriptionPlans': subscriptionPlans,
      'averageRevenue': averageRevenue,
      'firstConversion': firstConversion.toIso8601String(),
      'lastConversion': lastConversion.toIso8601String(),
    };
  }
}

class MonthlyTrend {
  final DateTime month;
  final double revenue;
  final int conversions;

  MonthlyTrend({
    required this.month,
    required this.revenue,
    required this.conversions,
  });

  factory MonthlyTrend.fromJson(Map<String, dynamic> json) {
    return MonthlyTrend(
      month: DateTime.parse(json['month'] as String),
      revenue: (json['revenue'] as num).toDouble(),
      conversions: json['conversions'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month.toIso8601String(),
      'revenue': revenue,
      'conversions': conversions,
    };
  }
}
