import '../entities/influencer_revenue.dart';
import '../entities/revenue_report.dart';

abstract class InfluencerRepository {
  // Revenue tracking
  Future<InfluencerRevenue> trackRevenue({
    required String userId,
    required String influencerCode,
    required String subscriptionPlan,
    required double amount,
    String? familyId,
  });

  Future<List<InfluencerRevenue>> getRevenueByCode(
    String userId,
    String code, {
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<InfluencerRevenue>> getAllRevenue(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  // Report generation
  Future<RevenueReport> generateReport(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<RevenueReport> generateMonthlyReport(String userId, int month, int year);

  Future<RevenueReport> generateYearlyReport(String userId, int year);

  // Analytics
  Future<List<CodeRevenue>> getTopInfluencers(
    String userId, {
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Map<String, dynamic>> getRevenueMetrics(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  // Export
  Future<String> exportToCSV(RevenueReport report);

  Future<String> exportToPDF(RevenueReport report);

  // Summary
  Future<double> getTotalRevenue(String userId);

  Future<double> getMonthlyRevenue(String userId);

  Future<double> getYearlyRevenue(String userId);

  Future<int> getTotalConversions(String userId);
}
