import 'package:flutter/material.dart';

import '../../../expenses/domain/entities/expense.dart';
import '../../data/services/bank_format_detector.dart';
import '../../data/services/duplicate_detector.dart';
import '../../domain/entities/bank_statement.dart';

class ImportProvider extends ChangeNotifier {
  BankStatement? _bankStatement;
  List<DuplicateDetectionResult> _duplicateMatches = [];
  bool _isProcessing = false;
  String? _error;
  bool _importCompleted = false;

  // Getters
  BankStatement? get bankStatement => _bankStatement;
  List<DuplicateDetectionResult> get duplicateMatches => _duplicateMatches;
  bool get isProcessing => _isProcessing;
  String? get error => _error;
  bool get importCompleted => _importCompleted;

  /// Parse PDF file and auto-detect bank format
  Future<void> parsePdfFile(
    String pdfPath, {
    String accountNumber = '',
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      _bankStatement = await BankFormatDetector.parseFromPdf(
        pdfPath,
        accountNumber: accountNumber,
      );
      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _bankStatement = null;
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Parse CSV file and auto-detect bank format
  Future<void> parseCsvFile(
    String csvContent, {
    String accountNumber = '',
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      _bankStatement = await BankFormatDetector.parseFromCsv(
        csvContent,
        accountNumber: accountNumber,
      );
      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _bankStatement = null;
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Detect duplicates between imported transactions and existing expenses
  Future<void> checkForDuplicates(List<Expense> existingExpenses) async {
    if (_bankStatement == null) return;

    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      _duplicateMatches = [];

      for (final transaction in _bankStatement!.transactions) {
        final matches = DuplicateDetector.findDuplicates(
          transaction,
          existingExpenses,
          dayThreshold: 3,
          amountThreshold: 0.05,
        );
        _duplicateMatches.addAll(matches);
      }

      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Get transactions that don't have duplicates
  List<BankStatementTransaction> getNonDuplicateTransactions() {
    if (_bankStatement == null) return [];

    final duplicateTransactionIds = _duplicateMatches
        .where((m) => m.isDuplicate)
        .map((m) => m.transaction)
        .toSet();

    return _bankStatement!.transactions
        .where((t) => !duplicateTransactionIds.contains(t))
        .toList();
  }

  /// Get duplicate match summary
  Map<String, int> getDuplicateSummary() {
    return {
      'total_transactions': _bankStatement?.transactions.length ?? 0,
      'potential_duplicates': _duplicateMatches
          .where((m) => m.confidenceScore >= 0.5)
          .length,
      'high_confidence': _duplicateMatches
          .where((m) => m.isDuplicate)
          .length,
    };
  }

  /// Clear and reset state
  void reset() {
    _bankStatement = null;
    _duplicateMatches = [];
    _isProcessing = false;
    _error = null;
    _importCompleted = false;
    notifyListeners();
  }

  /// Mark import as completed (after user confirms import)
  void markImportCompleted() {
    _importCompleted = true;
    notifyListeners();
  }

  /// Get detected bank format
  BankFormat? getDetectedFormat() {
    if (_bankStatement == null) return null;

    final bankName = _bankStatement!.bankName.toLowerCase();
    if (bankName.contains('habib')) return BankFormat.hbl;
    if (bankName.contains('meezan')) return BankFormat.meezan;
    if (bankName.contains('mcb')) return BankFormat.mcb;
    if (bankName.contains('standard')) return BankFormat.standardChartered;

    return BankFormat.unknown;
  }
}
