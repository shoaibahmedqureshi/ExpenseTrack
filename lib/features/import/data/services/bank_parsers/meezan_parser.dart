import '../../../domain/entities/bank_statement.dart';

/// Meezan Bank CSV Parser
/// Format: Transaction Date, Description, Amount, Balance, Type
class MeezanParser {
  static Future<BankStatement> parse(String csvContent, {String accountNumber = ''}) async {
    final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) throw Exception('Empty CSV file');

    // Skip header row if present
    int startRow = 0;
    if (lines[0].toLowerCase().contains('date') || lines[0].toLowerCase().contains('transaction')) {
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
        if (parts.length < 4) continue;

        final date = _parseDate(parts[0]);
        final description = parts[1].trim();
        final amount = _parseAmount(parts[2]);
        final balance = _parseAmount(parts[3]);
        final type = parts.length > 4 ? parts[4].trim().toLowerCase() : '';

        if (date == null || amount == 0) continue;

        // Track opening/closing balances
        if (i == startRow) openingBalance = balance;
        closingBalance = balance;

        // Determine transaction type (DR/CR or Debit/Credit)
        final isDebit = type.contains('debit') ||
                       type.contains('dr') ||
                       type.contains('withdrawal') ||
                       type.contains('payment');

        transactions.add(BankStatementTransaction(
          date: date,
          description: description,
          amount: amount,
          type: isDebit ? 'debit' : 'credit',
        ));
      } catch (e) {
        print('Error parsing Meezan row $i: $e');
        continue;
      }
    }

    return BankStatement(
      bankName: 'Meezan Bank',
      accountNumber: accountNumber,
      periodStart: transactions.isNotEmpty ? transactions.first.date : DateTime.now(),
      periodEnd: transactions.isNotEmpty ? transactions.last.date : DateTime.now(),
      transactions: transactions,
      openingBalance: openingBalance ?? 0,
      closingBalance: closingBalance ?? 0,
    );
  }

  static List<String> _parseCsvLine(String line) {
    // Handle quoted fields in CSV
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
    // Meezan uses: DD/MM/YYYY or YYYY-MM-DD
    final patterns = [
      RegExp(r'^(\d{2})/(\d{2})/(\d{4})$'),
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(dateStr);
      if (match != null) {
        try {
          if (pattern.pattern.startsWith('^\\(\\\\d{2}\\)')) {
            // DD/MM/YYYY format
            final day = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final year = int.parse(match.group(3)!);
            return DateTime(year, month, day);
          } else {
            // YYYY-MM-DD format
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
        .replaceAll(RegExp(r'[^\d.,]'), '')
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
}
