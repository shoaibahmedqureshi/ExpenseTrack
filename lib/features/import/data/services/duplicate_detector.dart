import '../../../expenses/domain/entities/expense.dart';
import '../../domain/entities/bank_statement.dart';

class DuplicateDetectionResult {
  final BankStatementTransaction transaction;
  final Expense? matchedExpense;
  final double confidenceScore; // 0-1, higher = more likely duplicate
  final String reason;

  DuplicateDetectionResult({
    required this.transaction,
    required this.matchedExpense,
    required this.confidenceScore,
    required this.reason,
  });

  bool get isDuplicate => confidenceScore >= 0.8;
}

/// Detects duplicate transactions between bank statement and existing expenses
class DuplicateDetector {
  /// Check if a bank transaction duplicates existing expenses
  static List<DuplicateDetectionResult> findDuplicates(
    BankStatementTransaction bankTxn,
    List<Expense> existingExpenses, {
    int dayThreshold = 3,
    double amountThreshold = 0.05, // 5% tolerance
  }) {
    final results = <DuplicateDetectionResult>[];

    for (final expense in existingExpenses) {
      final score = _calculateSimilarityScore(
        bankTxn,
        expense,
        dayThreshold: dayThreshold,
        amountThreshold: amountThreshold,
      );

      if (score > 0.5) {
        results.add(DuplicateDetectionResult(
          transaction: bankTxn,
          matchedExpense: expense,
          confidenceScore: score,
          reason: _generateReason(bankTxn, expense),
        ));
      }
    }

    // Sort by confidence score (highest first)
    results.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
    return results;
  }

  /// Score 0..1 out of a fixed 100 points: amount 50, date 40, description 10.
  /// The amount must match (within tolerance) or the pair is not a candidate —
  /// a same-day expense of a different amount is never a duplicate.
  static double _calculateSimilarityScore(
    BankStatementTransaction bankTxn,
    Expense expense, {
    required int dayThreshold,
    required double amountThreshold,
  }) {
    final amountDiff = (bankTxn.amount - expense.amount).abs();
    final allowed = (expense.amount * amountThreshold).clamp(0.01, double.infinity);
    if (amountDiff > allowed) return 0;
    final amountPoints = 50 * (1 - amountDiff / allowed);

    final daysDiff = bankTxn.date.difference(expense.date).inDays.abs();
    final datePoints =
        daysDiff <= dayThreshold ? 40 * (1 - daysDiff / (dayThreshold + 1)) : 0.0;

    final similarity = _stringSimilarity(
      bankTxn.description.toLowerCase(),
      expense.title.toLowerCase(),
    );
    final descPoints = similarity > 0.6 ? 10 * similarity : 0.0;

    return (amountPoints + datePoints + descPoints) / 100;
  }

  /// Simple string similarity (Levenshtein-inspired)
  static double _stringSimilarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // Check if one string contains the other
    if (s1.contains(s2) || s2.contains(s1)) return 0.9;

    // Levenshtein distance
    final distance = _levenshteinDistance(s1, s2);
    final maxLength = (s1.length > s2.length ? s1.length : s2.length).toDouble();

    return 1 - (distance / maxLength);
  }

  static int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    final d = List<List<int>>.generate(
      len1 + 1,
      (i) => List<int>.filled(len2 + 1, 0),
    );

    for (int i = 0; i <= len1; i++) d[i][0] = i;
    for (int j = 0; j <= len2; j++) d[0][j] = j;

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,     // deletion
          d[i][j - 1] + 1,     // insertion
          d[i - 1][j - 1] + cost // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return d[len1][len2];
  }

  static String _generateReason(
    BankStatementTransaction bankTxn,
    Expense expense,
  ) {
    final daysDiff = bankTxn.date.difference(expense.date).inDays.abs();
    final amountMatch = (bankTxn.amount - expense.amount).abs() < 0.01;

    if (daysDiff == 0 && amountMatch) {
      return 'Exact match: Same date and amount';
    } else if (amountMatch) {
      return 'Amount matches, dated $daysDiff days apart';
    } else if (daysDiff <= 1) {
      return 'Date matches, amount differs by ${(bankTxn.amount - expense.amount).abs().toStringAsFixed(2)}';
    } else {
      return 'Possible duplicate: dated $daysDiff days apart';
    }
  }
}
