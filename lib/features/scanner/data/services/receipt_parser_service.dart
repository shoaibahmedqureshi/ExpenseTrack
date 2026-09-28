import '../../domain/entities/scanned_receipt.dart';

class ReceiptParserService {
  static const double _confidenceThreshold = 0.5;

  /// Main entry point: parse receipt text and extract structured data
  Future<ScannedReceipt> parseReceipt(String rawText) async {
    final lines = rawText.split('\n').where((l) => l.trim().isNotEmpty).toList();

    String? merchant = _extractMerchant(lines);
    double? total = _extractTotal(lines);
    double? tax = _extractTax(lines);
    List<LineItem>? lineItems = _extractLineItems(lines);
    DateTime? date = _extractDate(lines);

    // Confidence scoring
    double confidence = 0.0;
    if (merchant != null) confidence += 0.3;
    if (total != null && total > 0) confidence += 0.4;
    if (tax != null && tax > 0) confidence += 0.2;
    if (date != null) confidence += 0.1;

    return ScannedReceipt(
      merchantName: merchant,
      totalAmount: total,
      taxAmount: tax,
      lineItems: lineItems,
      transactionDate: date,
      rawText: rawText,
      confidence: confidence,
    );
  }

  /// Strategy 1: Extract merchant name from top of receipt
  /// Usually first meaningful text line(s) before amounts
  String? _extractMerchant(List<String> lines) {
    if (lines.isEmpty) return null;

    // Filter out common noise words
    const noisePatterns = [
      r'^\d{1,2}:\d{2}',  // Time
      r'^\d{2}-\d{2}-\d{4}',  // Date formats
      r'^\d{2}/\d{2}/\d{4}',
      r'(?:thank|welcome|visit)',  // Generic closing
      r'(?:invoice|receipt|bill)',  // Document type labels
    ];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Skip noise
      if (noisePatterns.any((p) => RegExp(p, caseSensitive: false).hasMatch(trimmed))) {
        continue;
      }

      // Skip if it looks like a monetary amount
      if (_looksLikeAmount(trimmed)) continue;

      // Merchant names are usually 2-10 words, mixed case, short
      if (trimmed.length < 50 && !trimmed.contains(RegExp(r'^\d{4,}'))) {
        return trimmed;
      }
    }

    return null;
  }

  /// Strategy 2: Extract total amount
  /// Look for patterns: "TOTAL:", "AMOUNT:", "TOTAL:", or the largest monetary amount
  double? _extractTotal(List<String> lines) {
    // Priority 1: Explicit "TOTAL" or "AMOUNT" labels
    for (final line in lines) {
      final match = RegExp(
        r'(?:TOTAL|AMOUNT|SUBTOTAL|GRAND\s+TOTAL)[\s:]*([0-9,.]+)',
        caseSensitive: false,
      ).firstMatch(line);

      if (match != null) {
        return _parseAmount(match.group(1) ?? '');
      }
    }

    // Priority 2: Find largest amount in receipt
    double? largest;
    for (final line in lines) {
      final amount = _extractAmountFromLine(line);
      if (amount != null && (largest == null || amount > largest)) {
        largest = amount;
      }
    }

    return largest;
  }

  /// Strategy 3: Extract tax amount
  /// Look for "TAX", "VAT", "GST", "SERVICE" patterns
  double? _extractTax(List<String> lines) {
    for (final line in lines) {
      final match = RegExp(
        r'(?:TAX|VAT|GST|SERVICE|ST)[\s:]*([0-9,.]+)',
        caseSensitive: false,
      ).firstMatch(line);

      if (match != null) {
        final amount = _parseAmount(match.group(1) ?? '');
        if (amount != null && amount > 0) {
          return amount;
        }
      }
    }

    return null;
  }

  /// Extract date from receipt (usually near top or bottom)
  DateTime? _extractDate(List<String> lines) {
    for (final line in lines) {
      // Common formats: MM/DD/YYYY, DD/MM/YYYY, MM-DD-YYYY, etc.
      final matches = RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{4})')
          .allMatches(line);

      for (final match in matches) {
        try {
          final month = int.parse(match.group(1) ?? '1');
          final day = int.parse(match.group(2) ?? '1');
          final year = int.parse(match.group(3) ?? '2000');

          // Validate ranges (handle MM/DD or DD/MM)
          if ((month >= 1 && month <= 12) && (day >= 1 && day <= 31)) {
            return DateTime(year, month, day);
          }
        } catch (_) {
          continue;
        }
      }
    }

    return null;
  }

  /// Extract line items (SKU, description, price)
  List<LineItem>? _extractLineItems(List<String> lines) {
    final items = <LineItem>[];

    for (final line in lines) {
      // Pattern: [SKU/CODE] DESCRIPTION [QTY] PRICE
      final match = RegExp(
        r'(?:^|\s)([A-Z0-9]{2,})?[\s]*(.+?)[\s]+(\d+(?:\.\d+)?)?[\s]*([0-9,.]+)\s*$',
        caseSensitive: false,
      ).firstMatch(line);

      if (match != null) {
        try {
          final description = match.group(2)?.trim() ?? '';
          final quantity = double.tryParse(match.group(3) ?? '1') ?? 1.0;
          final totalPrice = _parseAmount(match.group(4) ?? '0') ?? 0.0;

          if (description.isNotEmpty && totalPrice > 0) {
            items.add(LineItem(
              description: description,
              quantity: quantity,
              unitPrice: totalPrice / quantity,
              totalPrice: totalPrice,
            ));
          }
        } catch (_) {
          continue;
        }
      }
    }

    return items.isNotEmpty ? items : null;
  }

  /// Extract monetary amount from a line
  /// Returns largest amount found, handles various formats: $1.99, 1,234.56, 99,99 (EU), etc.
  double? _extractAmountFromLine(String line) {
    final matches = RegExp(r'[0-9]{1,3}(?:[,.][0-9]{3})*[,.][0-9]{2}\b|[0-9]+[,.][0-9]{2}')
        .allMatches(line);

    double? largest;
    for (final match in matches) {
      final amount = _parseAmount(match.group(0) ?? '');
      if (amount != null && (largest == null || amount > largest)) {
        largest = amount;
      }
    }

    return largest;
  }

  /// Parse a monetary string into double (handles multiple formats)
  /// Supports: 1234.56, 1,234.56, 1.234,56 (EU), etc.
  double? _parseAmount(String s) {
    if (s.isEmpty) return null;

    final cleaned = s.trim().replaceAll(RegExp(r'[^\d.,]'), '');
    if (cleaned.isEmpty) return null;

    try {
      // Detect decimal separator (last occurrence of . or ,)
      final lastDot = cleaned.lastIndexOf('.');
      final lastComma = cleaned.lastIndexOf(',');

      String normalized;
      if (lastDot > lastComma) {
        // US/UK format: 1,234.56 → 1234.56
        normalized = cleaned.replaceAll(',', '');
      } else if (lastComma > lastDot) {
        // EU format: 1.234,56 → 1234.56
        normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = cleaned;
      }

      return double.parse(normalized);
    } catch (_) {
      return null;
    }
  }

  /// Quick check: does a line look like a monetary amount?
  bool _looksLikeAmount(String s) {
    return RegExp(r'[0-9,.]{3,}\s*$').hasMatch(s);
  }
}
