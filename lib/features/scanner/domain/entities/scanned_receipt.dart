class ScannedReceipt {
  final String? merchantName;
  final double? totalAmount;
  final double? taxAmount;
  final List<LineItem>? lineItems;
  final DateTime? transactionDate;
  final String? rawText;
  final double confidence;

  ScannedReceipt({
    this.merchantName,
    this.totalAmount,
    this.taxAmount,
    this.lineItems,
    this.transactionDate,
    this.rawText,
    this.confidence = 0.0,
  });

  bool get isValid => totalAmount != null && (totalAmount ?? 0) > 0;
}

class LineItem {
  final String description;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  LineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });
}
