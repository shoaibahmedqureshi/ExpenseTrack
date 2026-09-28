import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/influencer_dashboard/presentation/providers/influencer_provider.dart';
import 'package:outlay/features/influencer_dashboard/domain/repositories/influencer_repository.dart';
import 'package:outlay/features/influencer_dashboard/domain/entities/influencer_revenue.dart';
import 'package:outlay/features/influencer_dashboard/domain/entities/revenue_report.dart';

class MockInfluencerRepository implements InfluencerRepository {
  List<InfluencerRevenue> mockRevenues = [];
  RevenueReport? mockReport;
  bool shouldThrow = false;

  @override
  Future<InfluencerRevenue> trackRevenue({
    required String userId,
    required String influencerCode,
    required String subscriptionPlan,
    required double amount,
    String? familyId,
  }) async {
    if (shouldThrow) throw Exception('Mock error');
    final revenue = InfluencerRevenue(
      id: 'id_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      familyId: familyId,
      influencerCode: influencerCode,
      subscriptionPlan: subscriptionPlan,
      revenueAmount: amount,
      currency: 'PKR',
      transactionDate: DateTime.now(),
      createdAt: DateTime.now(),
    );
    mockRevenues.insert(0, revenue);
    return revenue;
  }

  @override
  Future<List<InfluencerRevenue>> getRevenueByCode(
    String userId,
    String code, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (shouldThrow) throw Exception('Mock error');
    return mockRevenues.where((r) => r.influencerCode == code).toList();
  }

  @override
  Future<List<InfluencerRevenue>> getAllRevenue(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (shouldThrow) throw Exception('Mock error');
    return mockRevenues;
  }

  @override
  Future<RevenueReport> generateReport(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (shouldThrow) throw Exception('Mock error');
    return mockReport ?? RevenueReport(
      totalRevenue: 0,
      monthlyRevenue: 0,
      yearlyRevenue: 0,
      totalConversions: 0,
      revenueByCode: [],
      monthlyTrends: [],
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<RevenueReport> generateMonthlyReport(String userId, int month, int year) async {
    return mockReport ?? RevenueReport(
      totalRevenue: 0,
      monthlyRevenue: 0,
      yearlyRevenue: 0,
      totalConversions: 0,
      revenueByCode: [],
      monthlyTrends: [],
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<RevenueReport> generateYearlyReport(String userId, int year) async {
    return mockReport ?? RevenueReport(
      totalRevenue: 0,
      monthlyRevenue: 0,
      yearlyRevenue: 0,
      totalConversions: 0,
      revenueByCode: [],
      monthlyTrends: [],
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<CodeRevenue>> getTopInfluencers(
    String userId, {
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> getRevenueMetrics(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return {};
  }

  @override
  Future<String> exportToCSV(RevenueReport report) async => '';

  @override
  Future<String> exportToPDF(RevenueReport report) async => '';

  @override
  Future<double> getTotalRevenue(String userId) async => 0;

  @override
  Future<double> getMonthlyRevenue(String userId) async => 0;

  @override
  Future<double> getYearlyRevenue(String userId) async => 0;

  @override
  Future<int> getTotalConversions(String userId) async => 0;
}

void main() {
  group('InfluencerProvider', () {
    late MockInfluencerRepository mockRepository;
    late InfluencerProvider provider;

    setUp(() {
      mockRepository = MockInfluencerRepository();
      provider = InfluencerProvider(repository: mockRepository);
    });

    test('initial state is correct', () {
      expect(provider.revenues, isEmpty);
      expect(provider.currentReport, isNull);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
      expect(provider.selectedCode, isNull);
    });

    test('loadRevenues loads data successfully', () async {
      final testRevenue = InfluencerRevenue(
        id: '1',
        userId: 'user_123',
        influencerCode: 'CODE001',
        subscriptionPlan: 'proMonthly',
        revenueAmount: 999.00,
        currency: 'PKR',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      mockRepository.mockRevenues = [testRevenue];

      await provider.loadRevenues('user_123');

      expect(provider.revenues, contains(testRevenue));
      expect(provider.error, isNull);
      expect(provider.isLoading, false);
    });

    test('trackRevenue adds new revenue', () async {
      await provider.trackRevenue(
        userId: 'user_123',
        influencerCode: 'CODE001',
        subscriptionPlan: 'proMonthly',
        amount: 999.00,
      );

      expect(provider.revenues.isNotEmpty, true);
      expect(provider.error, isNull);
    });

    test('generateReport creates report', () async {
      final testReport = RevenueReport(
        totalRevenue: 5000.00,
        monthlyRevenue: 500.00,
        yearlyRevenue: 5000.00,
        totalConversions: 5,
        revenueByCode: [],
        monthlyTrends: [],
        generatedAt: DateTime.now(),
      );

      mockRepository.mockReport = testReport;

      await provider.generateReport('user_123');

      expect(provider.currentReport, testReport);
      expect(provider.currentReport!.totalRevenue, 5000.00);
    });

    test('loadCodeRevenues filters by code', () async {
      final testRevenue = InfluencerRevenue(
        id: '1',
        userId: 'user_123',
        influencerCode: 'CODE001',
        subscriptionPlan: 'proMonthly',
        revenueAmount: 999.00,
        currency: 'PKR',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      mockRepository.mockRevenues = [testRevenue];

      await provider.loadCodeRevenues('user_123', 'CODE001');

      expect(provider.selectedCode, 'CODE001');
      expect(provider.revenues.first.influencerCode, 'CODE001');
    });

    test('clear resets all state', () async {
      final testRevenue = InfluencerRevenue(
        id: '1',
        userId: 'user_123',
        influencerCode: 'CODE001',
        subscriptionPlan: 'proMonthly',
        revenueAmount: 999.00,
        currency: 'PKR',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      mockRepository.mockRevenues = [testRevenue];
      await provider.loadRevenues('user_123');

      expect(provider.revenues.isNotEmpty, true);

      provider.clear();

      expect(provider.revenues, isEmpty);
      expect(provider.currentReport, isNull);
      expect(provider.error, isNull);
      expect(provider.selectedCode, isNull);
    });
  });
}
