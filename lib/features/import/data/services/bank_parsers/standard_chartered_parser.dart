import '../../../domain/entities/bank_statement.dart';

/// Standard Chartered Bank CSV Parser
/// Format: Date, Description, Amount, Running Balance
/// Supports multi-currency accounts
class StandardCharteredParser {
  static Future<BankStatement> parse(String csvContent, {String accountNumber = ''}) async {
    final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) throw Exception('Empty CSV file');

    int startRow = 0;
    if (lines[0].toLowerCase().contains('date') || lines[0].toLowerCase().contains('description')) {
      startRow = 1;
    }

    final transactions = <BankStatementTransaction>[];
    double? openingBalance;
    double? closingBalance;
    String? currency;

    for (int i = startRow; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final parts = _parseCsvLine(line);
        if (parts.length < 3) continue;

        final date = _parseDate(parts[0]);
        final description = parts[1].trim();
        final amountStr = parts[2].trim();
        final balance = parts.length > 3 ? _parseAmount(parts[3]) : 0.0;

        if (date == null) continue;

        // Extract currency from amount (SC includes currency code)
        final amountParsed = _parseAmountWithCurrency(amountStr);
        final amount = amountParsed['amount'] as double;
        if (amountParsed['currency'] != null) {
          currency ??= amountParsed['currency'] as String;
        }

        if (amount == 0) continue;

        if (i == startRow) openingBalance = balance;
        closingBalance = balance;

        // SC uses signed amounts (negative = debit, positive = credit)
        transactions.add(BankStatementTransaction(
          date: date,
          description: description,
          amount: amount.abs(),
          type: amount < 0 ? 'debit' : 'credit',
        ));
      } catch (e) {
        print('Error parsing Standard Chartered row $i: $e');
        continue;
      }
    }

    return BankStatement(
      bankName: 'Standard Chartered Bank',
      accountNumber: accountNumber,
      periodStart: transactions.isNotEmpty ? transactions.first.date : DateTime.now(),
      periodEnd: transactions.isNotEmpty ? transactions.last.date : DateTime.now(),
      transactions: transactions,
      openingBalance: openingBalance ?? 0,
      closingBalance: closingBalance ?? 0,
    );
  }

  static List<String> _parseCsvLine(String line) {
    final parts = <String>[];
    String current = '';
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        parts.add(current.replaceAll('"', '').trim());
        current = '';
      } else {
        current += char;
      }
    }

    if (current.isNotEmpty) {
      parts.add(current.replaceAll('"', '').trim());
    }

    return parts;
  }

  static DateTime? _parseDate(String dateStr) {
    // SC formats: DD/MM/YYYY or YYYY-MM-DD or MMM DD, YYYY
    final patterns = [
      RegExp(r'^(\d{2})/(\d{2})/(\d{4})$'),
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(dateStr);
      if (match != null) {
        try {
          if (pattern.pattern.contains('\\(\\\\d{2}\\)/')) {
            // DD/MM/YYYY
            final day = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final year = int.parse(match.group(3)!);
            return DateTime(year, month, day);
          } else {
            // YYYY-MM-DD
            final year = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final day = int.parse(match.group(3)!);
            return DateTime(year, month, day);
          }
        } catch (_) {
          continue;
        }
      }
    }

    return null;
  }

  static double _parseAmount(String amountStr) {
    if (amountStr.isEmpty) return 0;

    final cleaned = amountStr
        .replaceAll(RegExp(r'[^\d.,\-]'), '')
        .trim();

    if (cleaned.isEmpty) return 0;

    try {
      final lastDot = cleaned.lastIndexOf('.');
      final lastComma = cleaned.lastIndexOf(',');

      String normalized;
      if (lastDot > lastComma) {
        normalized = cleaned.replaceAll(',', '');
      } else if (lastComma > lastDot) {
        normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = cleaned;
      }

      return double.parse(normalized);
    } catch (_) {
      return 0;
    }
  }

  /// Parse amount and extract currency code
  /// Format: "PKR 10,000.00" or "-USD 500.00"
  static Map<String, dynamic> _parseAmountWithCurrency(String amountStr) {
    if (amountStr.isEmpty) return {'amount': 0.0, 'currency': null};

    // Extract currency (3 letter code)
    final currencyMatch = RegExp(r'([A-Z]{3})').firstMatch(amountStr);
    final currency = currencyMatch?.group(1);

    // Extract amount
    final amount = _parseAmount(amountStr);

    return {
      'amount': amount,
      'currency': currency,
    };
  }
}
