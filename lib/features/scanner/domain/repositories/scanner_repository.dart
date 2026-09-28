import '../entities/scanned_receipt.dart';

abstract class ScannerRepository {
  /// Extract text from an image using ML Kit
  Future<String> extractTextFromImage(String imagePath);

  /// Parse receipt text and extract structured data
  Future<ScannedReceipt> parseReceiptText(String rawText);

  /// Process image file from camera
  Future<ScannedReceipt> processReceiptImage(String imagePath);

  /// Save OCR debug log (testing only)
  Future<void> saveOcrDebugLog({
    required String rawText,
    required String? merchant,
    required double? total,
    required double? tax,
  });
}
