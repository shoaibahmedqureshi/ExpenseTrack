import 'package:flutter/foundation.dart';
import '../../domain/entities/influencer_revenue.dart';
import '../../domain/entities/revenue_report.dart';
import '../../domain/repositories/influencer_repository.dart';

class InfluencerProvider extends ChangeNotifier {
  final InfluencerRepository repository;

  List<InfluencerRevenue> _revenues = [];
  RevenueReport? _currentReport;
  bool _isLoading = false;
  String? _error;
  String? _selectedCode;

  InfluencerProvider({required this.repository});

  // Getters
  List<InfluencerRevenue> get revenues => _revenues;
  RevenueReport? get currentReport => _currentReport;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCode => _selectedCode;

  // Load all revenues for user
  Future<void> loadRevenues(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _revenues = await repository.getAllRevenue(
        userId,
        startDate: startDate,
        endDate: endDate,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Track new revenue
  Future<void> trackRevenue({
    required String userId,
    required String influencerCode,
    required String subscriptionPlan,
    required double amount,
    String? familyId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final revenue = await repository.trackRevenue(
        userId: userId,
        influencerCode: influencerCode,
        subscriptionPlan: subscriptionPlan,
        amount: amount,
        familyId: familyId,
      );
      _revenues.insert(0, revenue);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Generate report
  Future<void> generateReport(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentReport = await repository.generateReport(
        userId,
        startDate: startDate,
        endDate: endDate,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get revenues for specific code
  Future<void> loadCodeRevenues(
    String userId,
    String code, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    _selectedCode = code;
    notifyListeners();

    try {
      _revenues = await repository.getRevenueByCode(
        userId,
        code,
        startDate: startDate,
        endDate: endDate,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get top influencers
  Future<List<CodeRevenue>> getTopInfluencers(
    String userId, {
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await repository.getTopInfluencers(
        userId,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  // Get metrics
  Future<Map<String, dynamic>> getMetrics(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await repository.getRevenueMetrics(
        userId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return {};
    }
  }

  // Export to CSV
  Future<String> exportToCSV() async {
    if (_currentReport == null) {
      _error = 'No report to export';
      notifyListeners();
      return '';
    }

    try {
      return await repository.exportToCSV(_currentReport!);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return '';
    }
  }

  // Clear state
  void clear() {
    _revenues = [];
    _currentReport = null;
    _isLoading = false;
    _error = null;
    _selectedCode = null;
    notifyListeners();
  }
}
