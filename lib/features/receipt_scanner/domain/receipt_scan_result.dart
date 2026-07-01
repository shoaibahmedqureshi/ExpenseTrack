class ReceiptScanResult {
  const ReceiptScanResult({
    this.merchant,
    this.total,
    this.tax,
    this.date,
    this.rawText = '',
  });

  final String? merchant;
  final double? total;
  final double? tax;
  final DateTime? date;
  final String rawText;

  bool get hasAnyData =>
      merchant != null || total != null || tax != null || date != null;

  ReceiptScanResult copyWith({
    String? merchant,
    double? total,
    double? tax,
    DateTime? date,
    String? rawText,
  }) {
    return ReceiptScanResult(
      merchant: merchant ?? this.merchant,
      total: total ?? this.total,
      tax: tax ?? this.tax,
      date: date ?? this.date,
      rawText: rawText ?? this.rawText,
    );
  }
}
