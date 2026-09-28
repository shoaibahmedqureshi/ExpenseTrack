import 'package:intl/intl.dart';

import '../../domain/entities/tax_report.dart';

class TaxExportService {
  /// Generate CSV export of tax report
  static String generateCsv(TaxReport report) {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00');

    // Header
    buffer.writeln('TAX REPORT');
    buffer.writeln('${report.reportTitle}');
    buffer.writeln('Period: ${dateFormat.format(report.startDate)} - ${dateFormat.format(report.endDate)}');
    buffer.writeln('');

    // Summary
    buffer.writeln('SUMMARY');
    buffer.writeln('Total Income,${currencyFormat.format(report.totalIncome)}');
    buffer.writeln('Total Expenses,${currencyFormat.format(report.totalExpenses)}');
    buffer.writeln('Net Income,${currencyFormat.format(report.netIncome)}');
    buffer.writeln('Currency,${report.currency}');
    buffer.writeln('');

    // Expenses by Category
    buffer.writeln('EXPENSES BY CATEGORY');
    buffer.writeln('Category,Amount');
    for (final entry in report.expensesByCategory.entries) {
      buffer.writeln('${entry.key.name},${currencyFormat.format(entry.value)}');
    }
    buffer.writeln('');

    // Tax Deductible Items
    if (report.deductibleItems.isNotEmpty) {
      buffer.writeln('TAX DEDUCTIBLE ITEMS');
      buffer.writeln('Date,Category,Description,Amount,Tax Rate,Tax Benefit');
      for (final item in report.deductibleItems) {
        buffer.writeln(
          '${dateFormat.format(item.date)},'
          '${item.category},'
          '"${item.description}",'
          '${currencyFormat.format(item.amount)},'
          '${item.taxRate}%,'
          '${currencyFormat.format(item.estimatedTaxBenefit)}'
        );
      }
      buffer.writeln('');
    }

    // Estimated Tax Liability
    buffer.writeln('ESTIMATED TAX LIABILITY');
    buffer.writeln('Tax Rate,${report.taxRatePercentage}%');
    buffer.writeln('Estimated Tax Liability,${currencyFormat.format(report.estimatedTaxLiability)}');
    buffer.writeln('Note: This is an estimate. Please consult a tax professional for accurate calculations.');

    return buffer.toString();
  }

  /// Generate JSON export
  static Map<String, dynamic> generateJson(TaxReport report) {
    return {
      'report_title': report.reportTitle,
      'period': {
        'start_date': report.startDate.toIso8601String(),
        'end_date': report.endDate.toIso8601String(),
      },
      'currency': report.currency,
      'summary': {
        'total_income': report.totalIncome,
        'total_expenses': report.totalExpenses,
        'net_income': report.netIncome,
      },
      'expenses_by_category': {
        for (final entry in report.expensesByCategory.entries)
          entry.key.name: entry.value,
      },
      'deductible_items': [
        for (final item in report.deductibleItems)
          {
            'date': item.date.toIso8601String(),
            'category': item.category,
            'description': item.description,
            'amount': item.amount,
            'tax_rate': item.taxRate,
            'tax_benefit': item.estimatedTaxBenefit,
          },
      ],
      'tax_summary': {
        'tax_rate': report.taxRate,
        'tax_rate_percentage': report.taxRatePercentage,
        'estimated_tax_liability': report.estimatedTaxLiability,
        'note': 'This is an estimate. Consult a tax professional for accuracy.',
      },
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Generate HTML report for browser/email
  static String generateHtml(TaxReport report) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${report.reportTitle}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #1f2937; line-height: 1.6; }
    .container { max-width: 800px; margin: 0 auto; padding: 40px 20px; }
    h1 { font-size: 28px; margin-bottom: 8px; }
    .subtitle { color: #6b7280; font-size: 14px; margin-bottom: 30px; }
    .section { margin-bottom: 40px; }
    .section-title { font-size: 16px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: #374151; margin-bottom: 16px; border-bottom: 2px solid #e5e7eb; padding-bottom: 8px; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 16px; }
    th, td { padding: 12px; text-align: right; }
    th { background: #f3f4f6; font-weight: 600; color: #374151; }
    td { border-bottom: 1px solid #e5e7eb; }
    td:first-child, th:first-child { text-align: left; }
    .amount { font-family: 'Courier New', monospace; font-weight: 500; }
    .highlight { background: #fef3c7; padding: 16px; border-radius: 6px; border-left: 4px solid #f59e0b; }
    .warning { color: #7c2d12; font-size: 13px; }
    .footer { border-top: 1px solid #e5e7eb; padding-top: 20px; color: #6b7280; font-size: 12px; margin-top: 40px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>${report.reportTitle}</h1>
    <div class="subtitle">
      Period: ${dateFormat.format(report.startDate)} - ${dateFormat.format(report.endDate)}
    </div>

    <div class="section">
      <div class="section-title">Summary</div>
      <table>
        <tr>
          <td>Total Income</td>
          <td class="amount">${currencyFormat.format(report.totalIncome)}</td>
        </tr>
        <tr>
          <td>Total Expenses</td>
          <td class="amount">${currencyFormat.format(report.totalExpenses)}</td>
        </tr>
        <tr>
          <td><strong>Net Income</strong></td>
          <td class="amount"><strong>${currencyFormat.format(report.netIncome)}</strong></td>
        </tr>
      </table>
    </div>

    <div class="section">
      <div class="section-title">Expenses by Category</div>
      <table>
        <thead>
          <tr>
            <th>Category</th>
            <th>Amount</th>
          </tr>
        </thead>
        <tbody>
          ${report.expensesByCategory.entries.map((e) =>
            '<tr><td>${e.key.name}</td><td class="amount">${currencyFormat.format(e.value)}</td></tr>'
          ).join('')}
        </tbody>
      </table>
    </div>

    ${report.deductibleItems.isNotEmpty ? '''
    <div class="section">
      <div class="section-title">Tax Deductible Items</div>
      <table>
        <thead>
          <tr>
            <th>Date</th>
            <th>Category</th>
            <th>Description</th>
            <th>Amount</th>
            <th>Tax Benefit</th>
          </tr>
        </thead>
        <tbody>
          ${report.deductibleItems.map((item) =>
            '<tr>'
            '<td>${dateFormat.format(item.date)}</td>'
            '<td>${item.category}</td>'
            '<td>${item.description}</td>'
            '<td class="amount">${currencyFormat.format(item.amount)}</td>'
            '<td class="amount">${currencyFormat.format(item.estimatedTaxBenefit)}</td>'
            '</tr>'
          ).join('')}
        </tbody>
      </table>
    </div>
    ''' : ''}

    <div class="highlight">
      <div><strong>Tax Rate: ${report.taxRatePercentage}%</strong></div>
      <div><strong>Estimated Tax Liability: ${currencyFormat.format(report.estimatedTaxLiability)}</strong></div>
      <div class="warning">Note: This is an estimate based on the configured tax rate. Please consult a tax professional for accurate calculations.</div>
    </div>

    <div class="footer">
      <p>Generated by Outlay on ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}</p>
      <p>This report is for informational purposes only and should not be considered professional tax advice.</p>
    </div>
  </div>
</body>
</html>
''';
  }
}
