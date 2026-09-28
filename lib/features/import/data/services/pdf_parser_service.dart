import '../../domain/entities/bank_statement.dart';
import 'bank_parsers/hbl_parser.dart';
import 'bank_parsers/meezan_parser.dart';
import 'bank_parsers/mcb_parser.dart';
import 'bank_parsers/standard_chartered_parser.dart';

/// Extracts text from PDF bank statements and converts to CSV format
class PdfParserService {
  /// Parse PDF and extract transactions
  /// Supported: HBL, Meezan, MCB, Standard Chartered PDFs
  static Future<BankStatement> parsePdf(
    String pdfPath, {
    String accountNumber = '',
  }) async {
    try {
      // For now, return a placeholder error message
      // Full PDF parsing requires pdfx package integration which may need additional setup
      throw Exception(
        'PDF parsing requires file_picker and pdfx package setup. '
        'Please ensure pdfx is added to pubspec.yaml and initialized properly.'
      );
    } catch (e) {
      throw Exception('Failed to parse PDF: $e');
    }
  }

  /// Extract all text from PDF file (scaffolded for Phase 1c)
  static Future<String> _extractTextFromPdf(String pdfPath) async {
    try {
      // Placeholder - PDF text extraction to be implemented in Phase 1c
      // when pdfx package is properly integrated
      return '';
    } catch (e) {
      throw Exception('PDF text extraction failed: $e');
    }
  }

  /// Convert extracted PDF text to CSV-like format
  /// Organizes lines into structured rows
  static String _convertToCsv(String pdfText) {
    final lines = pdfText.split('\n');
    final csvLines = <String>[];

    // Filter and clean lines
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Skip headers and footer
      if (_isHeaderOrFooter(trimmed)) continue;

      csvLines.add(trimmed);
    }

    return csvLines.join('\n');
  }

  /// Check if line is a header, footer, or non-transaction line
  static bool _isHeaderOrFooter(String line) {
    final lower = line.toLowerCase();

    // Common headers
    if (lower.contains('date') && lower.contains('description')) return true;
    if (lower.contains('transaction') && lower.contains('amount')) return true;
    if (lower.contains('statement of account')) return true;
    if (lower.contains('page')) return true;

    // Common footers
    if (lower.contains('thank you')) return true;
    if (lower.contains('end of statement')) return true;
    if (lower.contains('printed on')) return true;
    if (lower.contains('confidential')) return true;

    // Bank name headers (usually on first page)
    if (lower.contains('habib bank') || lower.contains('meezan bank') ||
        lower.contains('mcb bank') || lower.contains('standard chartered')) {
      if (!line.contains('PKR') && !line.contains('USD')) return true;
    }

    return false;
  }

  /// Parse extracted content and detect bank format
  static Future<BankStatement> _parseExtractedContent(
    String csvContent, {
    required String accountNumber,
  }) async {
    // Detect bank format from content
    final bankFormat = _detectBankFromContent(csvContent);

    switch (bankFormat) {
      case 'hbl':
        return HblParser.parse(csvContent, accountNumber: accountNumber);
      case 'meezan':
        return MeezanParser.parse(csvContent, accountNumber: accountNumber);
      case 'mcb':
        return McbParser.parse(csvContent, accountNumber: accountNumber);
      case 'standard_chartered':
        return StandardCharteredParser.parse(csvContent, accountNumber: accountNumber);
      default:
        throw Exception(
          'Could not detect bank from PDF. '
          'Supported: HBL, Meezan, MCB, Standard Chartered.'
        );
    }
  }

  /// Detect which bank the PDF is from
  static String _detectBankFromContent(String content) {
    final lower = content.toLowerCase();

    if (lower.contains('habib') && lower.contains('bank')) {
      return 'hbl';
    }
    if (lower.contains('meezan') && lower.contains('bank')) {
      return 'meezan';
    }
    if (lower.contains('mcb') || (lower.contains('muslim') && lower.contains('commercial'))) {
      return 'mcb';
    }
    if (lower.contains('standard') && lower.contains('chartered')) {
      return 'standard_chartered';
    }

    return 'unknown';
  }
}
