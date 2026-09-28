import '../../domain/entities/bank_statement.dart';
import 'bank_parsers/hbl_parser.dart';
import 'bank_parsers/meezan_parser.dart';
import 'bank_parsers/mcb_parser.dart';
import 'bank_parsers/standard_chartered_parser.dart';
import 'pdf_parser_service.dart';

enum BankFormat {
  hbl,
  meezan,
  mcb,
  standardChartered,
  unknown,
}

/// Auto-detects bank format from CSV headers and parses accordingly
class BankFormatDetector {
  static Future<BankStatement> parseFromCsv(
    String csvContent, {
    String accountNumber = '',
  }) async {
    final format = _detectFormat(csvContent);

    switch (format) {
      case BankFormat.hbl:
        return HblParser.parse(csvContent, accountNumber: accountNumber);
      case BankFormat.meezan:
        return MeezanParser.parse(csvContent, accountNumber: accountNumber);
      case BankFormat.mcb:
        return McbParser.parse(csvContent, accountNumber: accountNumber);
      case BankFormat.standardChartered:
        return StandardCharteredParser.parse(csvContent, accountNumber: accountNumber);
      case BankFormat.unknown:
        throw Exception(
          'Could not detect bank format. '
          'Supported: HBL, Meezan, MCB, Standard Chartered. '
          'Please verify the CSV format and try again.'
        );
    }
  }

  /// Parse PDF file (auto-extracts text and detects format)
  static Future<BankStatement> parseFromPdf(
    String pdfPath, {
    String accountNumber = '',
  }) async {
    return PdfParserService.parsePdf(pdfPath, accountNumber: accountNumber);
  }

  static BankFormat _detectFormat(String csvContent) {
    final lines = csvContent.split('\n');
    if (lines.isEmpty) return BankFormat.unknown;

    final headerLine = lines[0].toLowerCase();

    // HBL: Date, Description, Debit, Credit, Balance
    if (headerLine.contains('debit') && headerLine.contains('credit')) {
      if (headerLine.contains('balance')) {
        return BankFormat.hbl;
      }
    }

    // Meezan: Transaction Date, Description, Amount, Balance, Type
    if (headerLine.contains('transaction') && headerLine.contains('amount')) {
      if (headerLine.contains('balance') && headerLine.contains('type')) {
        return BankFormat.meezan;
      }
    }

    // MCB: Date, Particulars, Debit, Credit, Balance
    if (headerLine.contains('particulars') && headerLine.contains('debit')) {
      return BankFormat.mcb;
    }

    // Standard Chartered: Date, Description, Amount, Running Balance
    if (headerLine.contains('running balance')) {
      return BankFormat.standardChartered;
    }

    // Fallback: Match on combination of keywords
    final hasDate = headerLine.contains('date');
    final hasDescription = headerLine.contains('description') ||
                          headerLine.contains('particulars') ||
                          headerLine.contains('transaction');
    final hasBalance = headerLine.contains('balance');

    if (!hasDate || !hasDescription || !hasBalance) {
      return BankFormat.unknown;
    }

    // Additional heuristics
    if (headerLine.contains('meezan')) return BankFormat.meezan;
    if (headerLine.contains('habib') || headerLine.contains('hbl')) return BankFormat.hbl;
    if (headerLine.contains('mcb')) return BankFormat.mcb;
    if (headerLine.contains('standard') || headerLine.contains('chartered')) {
      return BankFormat.standardChartered;
    }

    // Default fallback: try HBL format (most common)
    return BankFormat.hbl;
  }

  static String formatName(BankFormat format) {
    switch (format) {
      case BankFormat.hbl:
        return 'Habib Bank Limited (HBL)';
      case BankFormat.meezan:
        return 'Meezan Bank';
      case BankFormat.mcb:
        return 'Muslim Commercial Bank (MCB)';
      case BankFormat.standardChartered:
        return 'Standard Chartered Bank';
      case BankFormat.unknown:
        return 'Unknown Bank Format';
    }
  }
}
