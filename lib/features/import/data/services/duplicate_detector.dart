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

  static double _calculateSimilarityScore(
    BankStatementTransaction bankTxn,
    Expense expense, {
    required int dayThreshold,
    required double amountThreshold,
  }) {
    double score = 0.0;
    int maxScore = 0;

    // 1. Date match (40 points)
    final daysDiff = bankTxn.date.difference(expense.date).inDays.abs();
    if (daysDiff <= dayThreshold) {
      score += (40 * (1 - (daysDiff / dayThreshold)));
      maxScore += 40;
    }

    // 2. Amount match (50 points)
    final amountDiff = (bankTxn.amount - expense.amount).abs();
    final maxAmountDiff = expense.amount * amountThreshold;
    if (amountDiff <= maxAmountDiff) {
      if (amountDiff == 0) {
        score += 50;
      } else {
        score += (50 * (1 - (amountDiff / maxAmountDiff)));
      }
      maxScore += 50;
    }

    // 3. Description match (10 points)
    final similarity = _stringSimilarity(
      bankTxn.description.toLowerCase(),
      expense.title.toLowerCase(),
    );
    if (similarity > 0.6) {
      score += (10 * similarity);
      maxScore += 10;
    }

    // Normalize to 0-1
    return maxScore > 0 ? score / maxScore : 0;
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
