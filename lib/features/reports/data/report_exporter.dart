import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../expenses/domain/entities/expense.dart';

class ReportExporter {
  ReportExporter._();

  static Future<void> exportCsv({
    required List<Expense> expenses,
    required String periodLabel,
  }) async {
    final buffer = StringBuffer('Date,Title,Category,Type,Amount\n');
    for (final e in expenses) {
      buffer.writeln([
        DateFormat('yyyy-MM-dd').format(e.date),
        _escape(e.title),
        _escape(e.category.name),
        e.isIncome ? 'Income' : 'Expense',
        e.amount.toStringAsFixed(2),
      ].join(','));
    }

    final file = await _writeTempFile(
      '${_safeName(periodLabel)}.csv',
      buffer.toString(),
    );
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Outlay report — $periodLabel',
    );
  }

  static Future<void> exportPdf({
    required List<Expense> expenses,
    required String periodLabel,
    required double totalIncome,
    required double totalExpense,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text('Outlay Report',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text(periodLabel, style: const pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Income: ${CurrencyFormatter.format(totalIncome)}'),
              pw.Text('Expense: ${CurrencyFormatter.format(totalExpense)}'),
              pw.Text(
                  'Net: ${CurrencyFormatter.format(totalIncome - totalExpense)}'),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Title', 'Category', 'Type', 'Amount'],
            data: expenses
                .map((e) => [
                      DateFormat('yyyy-MM-dd').format(e.date),
                      e.title,
                      e.category.name,
                      e.isIncome ? 'Income' : 'Expense',
                      CurrencyFormatter.format(e.amount),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    final file = await _writeTempFileBytes(
      '${_safeName(periodLabel)}.pdf',
      await doc.save(),
    );
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Outlay report — $periodLabel',
    );
  }

  static Future<File> _writeTempFile(String name, String contents) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    return file.writeAsString(contents);
  }

  static Future<File> _writeTempFileBytes(String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    return file.writeAsBytes(bytes);
  }

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _safeName(String label) =>
      'outlay-report-${label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}';
}
