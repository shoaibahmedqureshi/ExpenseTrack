import 'package:intl/intl.dart';
import '../domain/receipt_scan_result.dart';

/// Parses raw OCR text from a receipt into structured fields.
///
/// Strategy for each field:
///   total   — look for the largest dollar amount near keywords
///             (total / grand total / amount due / balance due).
///             Falls back to the largest amount on the page.
///   date    — try common date formats in order of specificity.
///   merchant— first non-trivial line that isn't a date/phone/address.
class ReceiptParser {
  ReceiptParser._();

  static ReceiptScanResult parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return ReceiptScanResult(
      rawText: rawText,
      total: _extractTotal(lines),
      date: _extractDate(lines),
      merchant: _extractMerchant(lines),
    );
  }

  // ── Total ─────────────────────────────────────────────────────────────────

  static final _totalKeywords = RegExp(
    r'\b(total|grand\s*total|amount\s*due|balance\s*due|subtotal|net\s*total)\b',
    caseSensitive: false,
  );

  // Matches $1,234.56 / 1,234.56 / 1234.56
  static final _amountRe =
      RegExp(r'\$?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})|\d+\.\d{2})');

  static double? _extractTotal(List<String> lines) {
    // 1. Prefer amounts on lines containing total-related keywords.
    for (final line in lines) {
      if (_totalKeywords.hasMatch(line)) {
        final amount = _largestAmountOnLine(line);
        if (amount != null) return amount;
      }
    }

    // 2. Fallback: largest amount on any line (receipts usually end with total).
    double? biggest;
    for (final line in lines) {
      final a = _largestAmountOnLine(line);
      if (a != null && (biggest == null || a > biggest)) biggest = a;
    }
    return biggest;
  }

  static double? _largestAmountOnLine(String line) {
    final matches = _amountRe.allMatches(line);
    double? best;
    for (final m in matches) {
      final raw = m.group(1)!.replaceAll(',', '');
      final v = double.tryParse(raw);
      if (v != null && (best == null || v > best)) best = v;
    }
    return best;
  }

  // ── Date ──────────────────────────────────────────────────────────────────

  static final _dateFormats = [
    DateFormat('MM/dd/yyyy'),
    DateFormat('MM-dd-yyyy'),
    DateFormat('MM/dd/yy'),
    DateFormat('MM-dd-yy'),
    DateFormat('dd/MM/yyyy'),
    DateFormat('dd-MM-yyyy'),
    DateFormat('MMMM d, yyyy'),
    DateFormat('MMM d, yyyy'),
    DateFormat('MMM dd yyyy'),
    DateFormat('yyyy-MM-dd'),
  ];

  static final _dateHintRe = RegExp(
    r'\b(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})'   // 01/25/2024
    r'|(\d{4}-\d{2}-\d{2})'                      // 2024-01-25
    r'|((?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{1,2},?\s+\d{4})',
    caseSensitive: false,
  );

  static DateTime? _extractDate(List<String> lines) {
    for (final line in lines) {
      final match = _dateHintRe.firstMatch(line);
      if (match == null) continue;
      final candidate = match.group(0)!.trim();
      for (final fmt in _dateFormats) {
        try {
          final d = fmt.parseLoose(candidate);
          if (d.year > 2000 && d.year < 2100) return d;
        } catch (_) {}
      }
    }
    return null;
  }

  // ── Merchant ──────────────────────────────────────────────────────────────

  // Lines that look like addresses, phone numbers, URLs, or receipt metadata.
  static final _skipLineRe = RegExp(
    r'(\d{3}[-.\s]\d{3}[-.\s]\d{4})'     // phone
    r'|(\d+\s+\w+\s+(st|ave|rd|blvd|dr|ln|way)\b)' // address
    r'|(www\.|http)'                       // url
    r'|(receipt|invoice|order|thank\s*you|cashier|server|table|date|time|tel|fax)'
    r'|(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})', // date-looking
    caseSensitive: false,
  );

  static String? _extractMerchant(List<String> lines) {
    for (final line in lines.take(8)) {
      if (line.length < 3) continue;
      if (_skipLineRe.hasMatch(line)) continue;
      // Must contain at least one letter word.
      if (!RegExp(r'[a-zA-Z]{2,}').hasMatch(line)) continue;
      return _toTitleCase(line);
    }
    return null;
  }

  static String _toTitleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty
          ? w
          : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
