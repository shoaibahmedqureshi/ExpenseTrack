class ReceiptScanResult {
  const ReceiptScanResult({
    this.merchant,
    this.total,
    this.date,
    this.rawText = '',
  });

  final String? merchant;
  final double? total;
  final DateTime? date;
  final String rawText;

  bool get hasAnyData => merchant != null || total != null || date != null;

  ReceiptScanResult copyWith({
    String? merchant,
    double? total,
    DateTime? date,
    String? rawText,
  }) {
    return ReceiptScanResult(
      merchant: merchant ?? this.merchant,
      total: total ?? this.total,
      date: date ?? this.date,
      rawText: rawText ?? this.rawText,
    );
  }
}
