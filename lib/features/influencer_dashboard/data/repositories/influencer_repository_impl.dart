import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/currency_totals.dart';
import '../../domain/entities/influencer_revenue.dart';
import '../../domain/entities/revenue_report.dart';
import '../../domain/repositories/influencer_repository.dart';
import '../../domain/revenue_report_builder.dart';
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
      query =
          query.gte('transaction_date', startDate.toUtc().toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('transaction_date', endDate.toUtc().toIso8601String());
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
    var query =
        supabase.from('influencer_revenue').select().eq('user_id', userId);

    if (startDate != null) {
      query =
          query.gte('transaction_date', startDate.toUtc().toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('transaction_date', endDate.toUtc().toIso8601String());
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
    final revenues =
        await getAllRevenue(userId, startDate: startDate, endDate: endDate);

    return buildRevenueReport(revenues, DateTime.now());
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
    final revenues =
        await getAllRevenue(userId, startDate: startDate, endDate: endDate);

    return groupRevenueByCode(revenues).take(limit).toList();
  }

  @override
  Future<Map<String, dynamic>> getRevenueMetrics(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final report =
        await generateReport(userId, startDate: startDate, endDate: endDate);

    return {
      'totalsByCurrency': report.totalsByCurrency,
      'monthlyByCurrency': report.monthlyByCurrency,
      'yearlyByCurrency': report.yearlyByCurrency,
      'totalConversions': report.totalConversions,
      'avgPerConversionByCurrency': report.averageByCurrencyTotals,
      'topCode': report.revenueByCode.isNotEmpty
          ? report.revenueByCode.first.code
          : 'N/A',
      'codeCount': report.revenueByCode.length,
    };
  }

  @override
  Future<String> exportToCSV(RevenueReport report) async =>
      revenueReportCsv(report);

  @override
  Future<String> exportToPDF(RevenueReport report) async {
    // Placeholder for PDF export - would use pdf package
    return 'PDF export not yet implemented';
  }

  @override
  Future<CurrencyTotals> getTotalRevenue(String userId) async {
    final response = await supabase
        .from('influencer_revenue')
        .select('revenue_amount, currency')
        .eq('user_id', userId);
    return _sum(response as List);
  }

  @override
  Future<CurrencyTotals> getMonthlyRevenue(String userId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final response = await supabase
        .from('influencer_revenue')
        .select('revenue_amount, currency')
        .eq('user_id', userId)
        .gte('transaction_date', startOfMonth.toUtc().toIso8601String());
    return _sum(response as List);
  }

  @override
  Future<CurrencyTotals> getYearlyRevenue(String userId) async {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);

    final response = await supabase
        .from('influencer_revenue')
        .select('revenue_amount, currency')
        .eq('user_id', userId)
        .gte('transaction_date', startOfYear.toUtc().toIso8601String());
    return _sum(response as List);
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
  CurrencyTotals _sum(List rows) {
    final out = <String, double>{};
    for (final r in rows) {
      final c = normalizeCurrency(r['currency'] as String?);
      out[c] = (out[c] ?? 0) + (r['revenue_amount'] as num).toDouble();
    }
    return out;
  }
}
