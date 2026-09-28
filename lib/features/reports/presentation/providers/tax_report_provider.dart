import 'package:flutter/material.dart';

import '../../../expenses/domain/entities/expense.dart';
import '../../domain/entities/tax_report.dart';
import '../../data/services/tax_export_service.dart';

class TaxReportProvider extends ChangeNotifier {
  TaxReport? _currentReport;
  bool _isGenerating = false;
  String? _error;
  double _taxRate = 0.15; // default: 15%

  // Getters
  TaxReport? get currentReport => _currentReport;
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  double get taxRate => _taxRate;

  /// Generate tax report for date range
  Future<void> generateReport(
    List<Expense> expenses, {
    required DateTime startDate,
    required DateTime endDate,
    double taxRate = 0.15,
    String currency = 'PKR',
  }) async {
    _isGenerating = true;
    _error = null;
    _taxRate = taxRate;
    notifyListeners();

    try {
      // Filter expenses for date range
      final periodExpenses = expenses.where((e) {
        return e.date.isAfter(startDate) && e.date.isBefore(endDate.add(Duration(days: 1)));
      }).toList();

      // Calculate totals by category
      final expensesByCategory = <dynamic, double>{};
      double totalExpenses = 0;

      for (final expense in periodExpenses) {
        final category = expense.category;
        expensesByCategory[category] = (expensesByCategory[category] ?? 0) + expense.amount;
        totalExpenses += expense.amount;
      }

      // TODO: Calculate totalIncome from income data when available
      final totalIncome = 0.0;

      // TODO: Identify tax deductible items (empty list for now)
      final deductibleItems = <TaxDeductibleItem>[];

      _currentReport = TaxReport(
        startDate: startDate,
        endDate: endDate,
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        totalTax: totalIncome * taxRate,
        expensesByCategory: expensesByCategory,
        deductibleItems: deductibleItems,
        currency: currency,
        taxRate: taxRate,
      );

      _isGenerating = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _currentReport = null;
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Update tax rate and regenerate report
  Future<void> updateTaxRate(double newRate) async {
    if (_currentReport == null) return;
    _taxRate = newRate;
    notifyListeners();
  }

  /// Export current report as CSV
  String exportCsv() {
    if (_currentReport == null) throw Exception('No report generated');
    return TaxExportService.generateCsv(_currentReport!);
  }

  /// Export current report as JSON
  Map<String, dynamic> exportJson() {
    if (_currentReport == null) throw Exception('No report generated');
    return TaxExportService.generateJson(_currentReport!);
  }

  /// Export current report as HTML
  String exportHtml() {
    if (_currentReport == null) throw Exception('No report generated');
    return TaxExportService.generateHtml(_currentReport!);
  }

  /// Clear current report
  void clear() {
    _currentReport = null;
    _error = null;
    _isGenerating = false;
    _taxRate = 0.15;
    notifyListeners();
  }
}
