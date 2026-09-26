import 'package:intl/intl.dart';

/// Represents a transaction parsed from SMS
class ParsedTransaction {
  final String id;
  final String bankName;
  final double amount;
  final String? category;
  final DateTime date;
  final String? description;
  final double? balance;
  final double confidence; // 0.0 to 1.0, percentage certainty
  final String smsBody;
  final bool isProcessed;

  ParsedTransaction({
    required this.id,
    required this.bankName,
    required this.amount,
    this.category,
    required this.date,
    this.description,
    this.balance,
    this.confidence = 1.0,
    required this.smsBody,
    this.isProcessed = false,
  });

  /// Human-readable time ago
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return DateFormat.yMd().format(date);
  }

  /// Format confidence as percentage
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(0)}%';

  ParsedTransaction copyWith({
    String? id,
    String? bankName,
    double? amount,
    String? category,
    DateTime? date,
    String? description,
    double? balance,
    double? confidence,
    String? smsBody,
    bool? isProcessed,
  }) {
    return ParsedTransaction(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      description: description ?? this.description,
      balance: balance ?? this.balance,
      confidence: confidence ?? this.confidence,
      smsBody: smsBody ?? this.smsBody,
      isProcessed: isProcessed ?? this.isProcessed,
    );
  }
}
