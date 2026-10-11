import '../currency_totals.dart';

class RevenueReport {
  final CurrencyTotals totalsByCurrency;
  final Map<String, int> conversionsByCurrency;
  final CurrencyTotals monthlyByCurrency;
  final CurrencyTotals yearlyByCurrency;
  final List<CodeRevenue> revenueByCode;
  final List<MonthlyTrend> monthlyTrends;
  final DateTime generatedAt;

  RevenueReport({
    required this.totalsByCurrency,
    required this.conversionsByCurrency,
    required this.monthlyByCurrency,
    required this.yearlyByCurrency,
    required this.revenueByCode,
    required this.monthlyTrends,
    required this.generatedAt,
  });

  int get totalConversions =>
      conversionsByCurrency.values.fold(0, (a, b) => a + b);

  /// Average per conversion in each currency.
  CurrencyTotals get averageByCurrencyTotals =>
      averageByCurrency(totalsByCurrency, conversionsByCurrency);
}

class CodeRevenue {
  final String code;
  final CurrencyTotals totalsByCurrency;
  final Map<String, int> conversionsByCurrency;
  final List<String> subscriptionPlans;
  final DateTime firstConversion;
  final DateTime lastConversion;

  CodeRevenue({
    required this.code,
    required this.totalsByCurrency,
    required this.conversionsByCurrency,
    required this.subscriptionPlans,
    required this.firstConversion,
    required this.lastConversion,
  });

  int get conversions => conversionsByCurrency.values.fold(0, (a, b) => a + b);

  CurrencyTotals get averageByCurrencyTotals =>
      averageByCurrency(totalsByCurrency, conversionsByCurrency);

  factory CodeRevenue.fromJson(Map<String, dynamic> json) {
    return CodeRevenue(
      code: json['code'] as String,
      totalsByCurrency: _doubles(json['totalsByCurrency']),
      conversionsByCurrency: _ints(json['conversionsByCurrency']),
      subscriptionPlans: List<String>.from(json['subscriptionPlans'] as List),
      firstConversion: DateTime.parse(json['firstConversion'] as String),
      lastConversion: DateTime.parse(json['lastConversion'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'totalsByCurrency': totalsByCurrency,
      'conversionsByCurrency': conversionsByCurrency,
      'subscriptionPlans': subscriptionPlans,
      'firstConversion': firstConversion.toIso8601String(),
      'lastConversion': lastConversion.toIso8601String(),
    };
  }
}

class MonthlyTrend {
  final DateTime month;
  final CurrencyTotals revenueByCurrency;
  final int conversions;

  MonthlyTrend({
    required this.month,
    required this.revenueByCurrency,
    required this.conversions,
  });

  factory MonthlyTrend.fromJson(Map<String, dynamic> json) {
    return MonthlyTrend(
      month: DateTime.parse(json['month'] as String),
      revenueByCurrency: _doubles(json['revenueByCurrency']),
      conversions: json['conversions'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month.toIso8601String(),
      'revenueByCurrency': revenueByCurrency,
      'conversions': conversions,
    };
  }
}

CurrencyTotals _doubles(Object? o) => {
      for (final e in (o as Map? ?? const {}).entries)
        e.key as String: (e.value as num).toDouble(),
    };

Map<String, int> _ints(Object? o) => {
      for (final e in (o as Map? ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    };
