import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/influencer_revenue.dart';
import '../../domain/entities/revenue_report.dart';
import '../../domain/repositories/influencer_repository.dart';
import '../models/influencer_revenue_model.dart';

class InfluencerRepositoryImpl implements InfluencerRepository {
  final SupabaseClient supabase;

  InfluencerRepositoryImpl({required this.supabase});

  @override
  Future<InfluencerRevenue> trackRevenue({
    required String userId,
    required String influencerCode,
    required String subscriptionPlan,
    required double amount,
    String? familyId,
  }) async {
    final response = await supabase
        .from('influencer_revenue')
        .insert({
          'user_id': userId,
          'family_id': familyId,
          'influencer_code': influencerCode,
          'subscription_plan': subscriptionPlan,
          'revenue_amount': amount,
          'currency': 'PKR',
          'transaction_date': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return InfluencerRevenueModel.fromJson(response);
  }

  @override
  Future<List<InfluencerRevenue>> getRevenueByCode(
    String userId,
    String code, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = supabase
        .from('influencer_revenue')
        .select()
        .eq('user_id', userId)
        .eq('influencer_code', code);

    if (startDate != null) {
      query = query.gte('transaction_date', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('transaction_date', endDate.toIso8601String());
    }

    final response = await query.order('transaction_date', ascending: false);
    return (response as List)
        .map((e) => InfluencerRevenueModel.fromJson(e))
        .toList();
  }

  @override
  Future<List<InfluencerRevenue>> getAllRevenue(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = supabase
        .from('influencer_revenue')
        .select()
        .eq('user_id', userId);

    if (startDate != null) {
      query = query.gte('transaction_date', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('transaction_date', endDate.toIso8601String());
    }

    final response = await query.order('transaction_date', ascending: false);
    return (response as List)
        .map((e) => InfluencerRevenueModel.fromJson(e))
        .toList();
  }

  @override
  Future<RevenueReport> generateReport(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final revenues = await getAllRevenue(userId,
        startDate: startDate, endDate: endDate);

    if (revenues.isEmpty) {
      return RevenueReport(
        totalRevenue: 0,
        monthlyRevenue: 0,
        yearlyRevenue: 0,
        totalConversions: 0,
        revenueByCode: [],
        monthlyTrends: [],
        generatedAt: DateTime.now(),
      );
    }

    // Calculate totals
    double totalRevenue =
        revenues.fold(0, (sum, r) => sum + r.revenueAmount);
    int totalConversions = revenues.length;

    // Calculate monthly and yearly
    final now = DateTime.now();
    final thisMonth = revenues
        .where((r) =>
            r.transactionDate.year == now.year &&
            r.transactionDate.month == now.month)
        .fold(0.0, (sum, r) => sum + r.revenueAmount);

    final thisYear = revenues
        .where((r) => r.transactionDate.year == now.year)
        .fold(0.0, (sum, r) => sum + r.revenueAmount);

    // Group by code
    final revenueByCode = _groupByCode(revenues);

    // Calculate monthly trends
    final monthlyTrends = _calculateMonthlyTrends(revenues);

    return RevenueReport(
      totalRevenue: totalRevenue,
      monthlyRevenue: thisMonth,
      yearlyRevenue: thisYear,
      totalConversions: totalConversions,
      revenueByCode: revenueByCode,
      monthlyTrends: monthlyTrends,
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<RevenueReport> generateMonthlyReport(
      String userId, int month, int year) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);

    return generateReport(userId, startDate: startDate, endDate: endDate);
  }

  @override
  Future<RevenueReport> generateYearlyReport(String userId, int year) async {
    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year, 12, 31);

    return generateReport(userId, startDate: startDate, endDate: endDate);
  }

  @override
  Future<List<CodeRevenue>> getTopInfluencers(
    String userId, {
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final revenues = await getAllRevenue(userId,
        startDate: startDate, endDate: endDate);

    final grouped = _groupByCode(revenues);
    grouped.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    return grouped.take(limit).toList();
  }

  @override
  Future<Map<String, dynamic>> getRevenueMetrics(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final report = await generateReport(userId,
        startDate: startDate, endDate: endDate);

    return {
      'totalRevenue': report.totalRevenue,
      'monthlyRevenue': report.monthlyRevenue,
      'yearlyRevenue': report.yearlyRevenue,
      'totalConversions': report.totalConversions,
      'avgPerConversion': report.averageRevenuePerConversion,
      'topCode': report.revenueByCode.isNotEmpty
          ? report.revenueByCode.first.code
          : 'N/A',
      'codeCount': report.revenueByCode.length,
    };
  }

  @override
  Future<String> exportToCSV(RevenueReport report) async {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('Influencer Code,Total Revenue,Conversions,Avg Revenue');

    // Data rows
    for (final code in report.revenueByCode) {
      buffer.writeln(
          '${code.code},${code.totalRevenue},${code.conversions},${code.averageRevenue}');
    }

    return buffer.toString();
  }

  @override
  Future<String> exportToPDF(RevenueReport report) async {
    // Placeholder for PDF export - would use pdf package
    return 'PDF export not yet implemented';
  }

  @override
  Future<double> getTotalRevenue(String userId) async {
    final response = await supabase
        .from('influencer_revenue')
        .select('revenue_amount')
        .eq('user_id', userId);

    return (response as List).fold<double>(
        0.0, (double sum, dynamic r) => sum + (r['revenue_amount'] as num).toDouble());
  }

  @override
  Future<double> getMonthlyRevenue(String userId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    var query = supabase
        .from('influencer_revenue')
        .select('revenue_amount')
        .eq('user_id', userId)
        .gte('transaction_date', startOfMonth.toIso8601String());

    final response = await query;
    return (response as List).fold<double>(
        0.0, (double sum, dynamic r) => sum + (r['revenue_amount'] as num).toDouble());
  }

  @override
  Future<double> getYearlyRevenue(String userId) async {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);

    var query = supabase
        .from('influencer_revenue')
        .select('revenue_amount')
        .eq('user_id', userId)
        .gte('transaction_date', startOfYear.toIso8601String());

    final response = await query;
    return (response as List).fold<double>(
        0.0, (double sum, dynamic r) => sum + (r['revenue_amount'] as num).toDouble());
  }

  @override
  Future<int> getTotalConversions(String userId) async {
    final response = await supabase
        .from('influencer_revenue')
        .select('id')
        .eq('user_id', userId);

    return (response as List).length;
  }

  // Helper methods
  List<CodeRevenue> _groupByCode(List<InfluencerRevenue> revenues) {
    final grouped = <String, List<InfluencerRevenue>>{};

    for (final revenue in revenues) {
      grouped.putIfAbsent(revenue.influencerCode, () => []).add(revenue);
    }

    return grouped.entries.map((e) {
      final code = e.key;
      final items = e.value;
      final total = items.fold(0.0, (sum, r) => sum + r.revenueAmount);
      final plans = items.map((r) => r.subscriptionPlan).toSet().toList();

      return CodeRevenue(
        code: code,
        totalRevenue: total,
        conversions: items.length,
        subscriptionPlans: plans,
        averageRevenue: total / items.length,
        firstConversion: items.last.transactionDate,
        lastConversion: items.first.transactionDate,
      );
    }).toList();
  }

  List<MonthlyTrend> _calculateMonthlyTrends(
      List<InfluencerRevenue> revenues) {
    final grouped = <DateTime, List<InfluencerRevenue>>{};

    for (final revenue in revenues) {
      final monthStart =
          DateTime(revenue.transactionDate.year, revenue.transactionDate.month);
      grouped.putIfAbsent(monthStart, () => []).add(revenue);
    }

    return grouped.entries.map((e) {
      final month = e.key;
      final items = e.value;
      final revenue = items.fold(0.0, (sum, r) => sum + r.revenueAmount);

      return MonthlyTrend(
        month: month,
        revenue: revenue,
        conversions: items.length,
      );
    }).toList()
      ..sort((a, b) => a.month.compareTo(b.month));
  }
}
