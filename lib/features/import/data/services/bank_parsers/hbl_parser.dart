import '../../../domain/entities/bank_statement.dart';

/// Habib Bank Limited (HBL) CSV Parser
/// Format: Date, Description, Debit, Credit, Balance
class HblParser {
  static Future<BankStatement> parse(String csvContent, {String accountNumber = ''}) async {
    final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) throw Exception('Empty CSV file');

    // Skip header row if present
    int startRow = 0;
    if (lines[0].toLowerCase().contains('date')) {
      startRow = 1;
    }

    final transactions = <BankStatementTransaction>[];
    double? openingBalance;
    double? closingBalance;

    for (int i = startRow; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final parts = _parseCsvLine(line);
        if (parts.length < 5) continue;

        final date = _parseDate(parts[0]);
        final description = parts[1].trim();
        final debit = _parseAmount(parts[2]);
        final credit = _parseAmount(parts[3]);
        final balance = _parseAmount(parts[4]);

        if (date == null) continue;

        // Track opening/closing balances
        if (i == startRow) openingBalance = balance;
        closingBalance = balance;

        // Determine transaction type
        if (debit > 0) {
          transactions.add(BankStatementTransaction(
            date: date,
            description: description,
            amount: debit,
            type: 'debit',
          ));
        } else if (credit > 0) {
          transactions.add(BankStatementTransaction(
            date: date,
            description: description,
            amount: credit,
            type: 'credit',
          ));
        }
      } catch (e) {
        // Log parsing error but continue with other rows
        print('Error parsing HBL row $i: $e');
        continue;
      }
    }

    return BankStatement(
      bankName: 'Habib Bank Limited (HBL)',
      accountNumber: accountNumber,
      periodStart: transactions.isNotEmpty ? transactions.first.date : DateTime.now(),
      periodEnd: transactions.isNotEmpty ? transactions.last.date : DateTime.now(),
      transactions: transactions,
      openingBalance: openingBalance ?? 0,
      closingBalance: closingBalance ?? 0,
    );
  }

  static List<String> _parseCsvLine(String line) {
    // Simple CSV parser (handles basic cases, not quoted fields)
    return line.split(',').map((s) => s.trim()).toList();
  }

  static DateTime? _parseDate(String dateStr) {
    // Support formats: DD/MM/YYYY, MM/DD/YYYY, DD-MM-YYYY, MM-DD-YYYY
    final patterns = [
      RegExp(r'^(\d{2})/(\d{2})/(\d{4})$'),
      RegExp(r'^(\d{2})-(\d{2})-(\d{4})$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(dateStr);
      if (match != null) {
        final first = int.parse(match.group(1) ?? '1');
        final second = int.parse(match.group(2) ?? '1');
        final year = int.parse(match.group(3) ?? '2000');

        // Assume DD/MM format for Pakistani banks
        try {
          return DateTime(year, second, first);
        } catch (_) {
          // Try MM/DD format
          try {
            return DateTime(year, first, second);
          } catch (_) {
            return null;
          }
        }
      }
    }

    return null;
  }

  static double _parseAmount(String amountStr) {
    if (amountStr.isEmpty) return 0;

    final cleaned = amountStr
        .replaceAll(RegExp(r'[^\d.,]'), '')
        .trim();

    if (cleaned.isEmpty) return 0;

    try {
      // Detect decimal separator (last occurrence of . or ,)
      final lastDot = cleaned.lastIndexOf('.');
      final lastComma = cleaned.lastIndexOf(',');

      String normalized;
      if (lastDot > lastComma) {
        // US format: 1,234.56
        normalized = cleaned.replaceAll(',', '');
      } else if (lastComma > lastDot) {
        // EU format: 1.234,56
        normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = cleaned;
      }

      return double.parse(normalized);
    } catch (_) {
      return 0;
    }
  }
}
