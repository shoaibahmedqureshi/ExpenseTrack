import 'package:flutter/material.dart';
import '../../domain/entities/sms_bank.dart';
import '../../domain/entities/parsed_transaction.dart';

/// Provider for SMS auto-logging feature
/// Manages state for SMS permission, bank configurations, and parsed transactions
class SmsProvider extends ChangeNotifier {
  bool _isSmsEnabled = false;
  bool _isLoading = false;
  final List<SmsBank> _banks = [];
  final List<ParsedTransaction> _recentTransactions = [];
  double _detectionAccuracy = 0.982; // 98.2%
  int _capturedThisWeek = 14;
  int _timeSavedMinutes = 45;

  // Getters
  bool get isSmsEnabled => _isSmsEnabled;
  bool get isLoading => _isLoading;
  List<SmsBank> get banks => _banks;
  List<ParsedTransaction> get recentTransactions => _recentTransactions;
  double get detectionAccuracy => _detectionAccuracy;
  int get capturedThisWeek => _capturedThisWeek;
  int get timeSavedMinutes => _timeSavedMinutes;
  int get activeBankCount => _banks.where((b) => b.isEnabled).length;

  SmsProvider() {
    _initializeBanks();
    _loadMockData();
  }

  /// Initialize the list of supported banks
  void _initializeBanks() {
    _banks.addAll([
      SmsBank(
        id: 'hbl',
        name: 'Habib Bank',
        shortCode: 'HBL',
        icon: Icons.account_balance,
        color: const Color(0xFF1a4d7a),
        isEnabled: true,
        parsedCount: 34,
      ),
      SmsBank(
        id: 'meezan',
        name: 'Meezan Bank',
        shortCode: 'MEZN',
        icon: Icons.savings,
        color: const Color(0xFF1d695d),
        isEnabled: true,
        parsedCount: 18,
      ),
      SmsBank(
        id: 'jazz',
        name: 'JazzCash',
        shortCode: 'JC',
        icon: Icons.account_balance_wallet,
        color: const Color(0xFFc41e3a),
        isEnabled: true,
        parsedCount: 12,
      ),
      SmsBank(
        id: 'easypaisa',
        name: 'EasyPaisa',
        shortCode: 'EP',
        icon: Icons.mobile_screen_share,
        color: const Color(0xFF00a651),
        isEnabled: true,
        parsedCount: 8,
      ),
      SmsBank(
        id: 'ubl',
        name: 'UBL & MCB',
        shortCode: 'UBL',
        icon: Icons.account_balance,
        color: const Color(0xFF808080),
        isEnabled: false,
        parsedCount: 0,
      ),
    ]);
  }

  /// Load mock SMS transactions for Phase 1a
  void _loadMockData() {
    final now = DateTime.now();
    _recentTransactions.addAll([
      ParsedTransaction(
        id: '1',
        bankName: 'HBL',
        amount: -2500,
        category: 'Shopping',
        date: now.subtract(const Duration(hours: 2)),
        description: 'Carrefour Transaction',
        balance: 64200,
        confidence: 0.98,
        smsBody: 'HBL Alert',
      ),
      ParsedTransaction(
        id: '2',
        bankName: 'Meezan',
        amount: -1500,
        category: 'Food & Dining',
        date: now.subtract(const Duration(hours: 5)),
        description: 'Restaurant Payment',
        balance: 35000,
        confidence: 0.95,
        smsBody: 'Meezan Alert',
      ),
      ParsedTransaction(
        id: '3',
        bankName: 'JazzCash',
        amount: -500,
        category: 'Utilities',
        date: now.subtract(const Duration(hours: 8)),
        description: 'Phone Bill',
        balance: 15250,
        confidence: 0.99,
        smsBody: 'Jazz Alert',
      ),
      ParsedTransaction(
        id: '4',
        bankName: 'HBL',
        amount: 50000,
        category: 'Salary',
        date: now.subtract(const Duration(days: 1)),
        description: 'Salary Deposit',
        balance: 64200,
        confidence: 1.0,
        smsBody: 'HBL Alert',
      ),
    ]);
  }

  /// Toggle SMS auto-logging
  Future<void> toggleSmsLogging(bool enabled) async {
    _isLoading = true;
    notifyListeners();

    // Simulate permission request/change
    await Future.delayed(const Duration(milliseconds: 500));

    _isSmsEnabled = enabled;
    _isLoading = false;
    notifyListeners();
  }

  /// Toggle a specific bank's SMS parsing
  Future<void> toggleBank(String bankId) async {
    final index = _banks.indexWhere((b) => b.id == bankId);
    if (index != -1) {
      _banks[index] = _banks[index].copyWith(
        isEnabled: !_banks[index].isEnabled,
      );
      notifyListeners();
    }
  }

  /// Get the percentage of recently captured transactions
  double get captureRate => _capturedThisWeek > 0 ? 0.95 : 0;
}
