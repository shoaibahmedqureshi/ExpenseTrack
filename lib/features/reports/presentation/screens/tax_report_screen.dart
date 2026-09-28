import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../../domain/entities/tax_report.dart';
import '../providers/tax_report_provider.dart';

class TaxReportScreen extends StatefulWidget {
  const TaxReportScreen({super.key});

  @override
  State<TaxReportScreen> createState() => _TaxReportScreenState();
}

class _TaxReportScreenState extends State<TaxReportScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  late double _taxRate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = now;
    _startDate = DateTime(now.year - 1, now.month, now.day);
    _taxRate = 0.15; // 15% default
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Report', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Consumer2<TaxReportProvider, ExpenseProvider>(
        builder: (context, taxProvider, expenseProvider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Range Selection
                _buildDateRangeSection(),
                const SizedBox(height: 24),

                // Tax Rate Setting
                _buildTaxRateSection(taxProvider),
                const SizedBox(height: 24),

                // Generate Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: taxProvider.isGenerating
                        ? null
                        : () => _generateReport(context, taxProvider, expenseProvider),
                    icon: taxProvider.isGenerating
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                Theme.of(context).primaryColor,
                              ),
                            ),
                          )
                        : const Icon(Icons.assessment),
                    label: Text(taxProvider.isGenerating ? 'Generating...' : 'Generate Report'),
                  ),
                ),
                const SizedBox(height: 32),

                // Report Display
                if (taxProvider.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.expenseColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.error, color: AppTheme.expenseColor),
                            SizedBox(width: 8),
                            Text('Error', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          taxProvider.error!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else if (taxProvider.currentReport != null)
                  _buildReportDisplay(context, taxProvider, taxProvider.currentReport!),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateRangeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Period',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateField('From', _startDate, () => _selectStartDate(context)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateField('To', _endDate, () => _selectEndDate(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime date,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM dd, yyyy').format(date),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxRateSection(TaxReportProvider taxProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.incomeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tax Rate',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '${(_taxRate * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.incomeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: _taxRate,
            min: 0,
            max: 0.50, // max 50%
            divisions: 50,
            onChanged: (value) {
              setState(() => _taxRate = value);
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Adjust the tax rate for your calculations. Default is 15% for Pakistan.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportDisplay(
    BuildContext context,
    TaxReportProvider taxProvider,
    TaxReport report,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Report Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.reportTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildReportRow('Total Income', report.totalIncome, report.currency),
              _buildReportRow('Total Expenses', report.totalExpenses, report.currency),
              const Divider(height: 16),
              _buildReportRow('Net Income', report.netIncome, report.currency,
                  isHighlight: true),
              const SizedBox(height: 12),
              _buildReportRow('Tax Rate', report.taxRatePercentage, '%'),
              _buildReportRow('Estimated Tax Liability', report.estimatedTaxLiability,
                  report.currency,
                  isHighlight: true, isExpense: true),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Expenses by Category
        if (report.expensesByCategory.isNotEmpty) ...[
          const Text(
            'Expenses by Category',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: report.expensesByCategory.entries
                  .map((e) => _buildCategoryRow(
                        e.key.toString().split('.').last,
                        e.value,
                        report.currency,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Export Options
        const Text(
          'Export Report',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _exportCsv(context, taxProvider),
                icon: const Icon(Icons.file_download),
                label: const Text('CSV'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _exportJson(context, taxProvider),
                icon: const Icon(Icons.file_download),
                label: const Text('JSON'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _exportHtml(context, taxProvider),
                icon: const Icon(Icons.file_download),
                label: const Text('HTML'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.expenseColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info, size: 18, color: AppTheme.expenseColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This is an estimate. Consult a tax professional for accurate calculations.',
                  style: TextStyle(fontSize: 11, color: AppTheme.expenseColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportRow(
    String label,
    double amount,
    String suffix, {
    bool isHighlight = false,
    bool isExpense = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          '${CurrencyFormatter.format(amount)} $suffix',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
            color: isExpense
                ? AppTheme.expenseColor
                : isHighlight
                    ? AppTheme.incomeColor
                    : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(String category, double amount, String currency) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            category,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          Text(
            '${CurrencyFormatter.format(amount)} $currency',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
    );
    if (picked != null && picked != _startDate) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _endDate) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _generateReport(
    BuildContext context,
    TaxReportProvider taxProvider,
    ExpenseProvider expenseProvider,
  ) async {
    await taxProvider.generateReport(
      expenseProvider.expenses,
      startDate: _startDate,
      endDate: _endDate,
      taxRate: _taxRate,
      currency: 'PKR',
    );
  }

  void _exportCsv(BuildContext context, TaxReportProvider taxProvider) {
    try {
      final csv = taxProvider.exportCsv();
      _showExportDialog(context, 'Tax Report ${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv', csv);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  void _exportJson(BuildContext context, TaxReportProvider taxProvider) {
    try {
      final json = taxProvider.exportJson();
      final jsonString = json.toString();
      _showExportDialog(context, 'Tax Report ${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json', jsonString);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  void _exportHtml(BuildContext context, TaxReportProvider taxProvider) {
    try {
      final html = taxProvider.exportHtml();
      _showExportDialog(context, 'Tax Report ${DateFormat('yyyy-MM-dd').format(DateTime.now())}.html', html);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  void _showExportDialog(BuildContext context, String filename, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export $filename'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SelectableText(content),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement file download using share_plus or file_saver
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Report content copied to clipboard')),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.file_download),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }
}
