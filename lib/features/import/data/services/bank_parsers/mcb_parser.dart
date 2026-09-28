import '../../../domain/entities/bank_statement.dart';

/// MCB Bank CSV Parser
/// Format: Date, Particulars, Debit, Credit, Balance
class McbParser {
  static Future<BankStatement> parse(String csvContent, {String accountNumber = ''}) async {
    final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) throw Exception('Empty CSV file');

    int startRow = 0;
    if (lines[0].toLowerCase().contains('date') || lines[0].toLowerCase().contains('particulars')) {
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
        final particulars = parts[1].trim();
        final debit = _parseAmount(parts[2]);
        final credit = _parseAmount(parts[3]);
        final balance = _parseAmount(parts[4]);

        if (date == null) continue;

        if (i == startRow) openingBalance = balance;
        closingBalance = balance;

        if (debit > 0) {
          transactions.add(BankStatementTransaction(
            date: date,
            description: particulars,
            amount: debit,
            type: 'debit',
          ));
        } else if (credit > 0) {
          transactions.add(BankStatementTransaction(
            date: date,
            description: particulars,
            amount: credit,
            type: 'credit',
          ));
        }
      } catch (e) {
        print('Error parsing MCB row $i: $e');
        continue;
      }
    }

    return BankStatement(
      bankName: 'Muslim Commercial Bank (MCB)',
      accountNumber: accountNumber,
      periodStart: transactions.isNotEmpty ? transactions.first.date : DateTime.now(),
      periodEnd: transactions.isNotEmpty ? transactions.last.date : DateTime.now(),
      transactions: transactions,
      openingBalance: openingBalance ?? 0,
      closingBalance: closingBalance ?? 0,
    );
  }

  static List<String> _parseCsvLine(String line) {
    // Handle quoted CSV fields
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
    // MCB formats: DD/MM/YYYY or YYYY-MM-DD
    final patterns = [
      RegExp(r'^(\d{2})/(\d{2})/(\d{4})$'),
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'),
      RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(dateStr);
      if (match != null) {
        try {
          if (match.groupCount >= 3) {
            final first = int.parse(match.group(1)!);
            final second = int.parse(match.group(2)!);
            final third = int.parse(match.group(3)!);

            // Determine format based on first group size
            if (first > 31) {
              // Likely YYYY-MM-DD
              return DateTime(first, second, third);
            } else {
              // Likely DD/MM/YYYY
              return DateTime(third, second, first);
            }
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
