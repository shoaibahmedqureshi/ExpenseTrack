import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/scanned_receipt.dart';
import '../../domain/repositories/scanner_repository.dart';
import '../services/receipt_parser_service.dart';

class ScannerRepositoryImpl implements ScannerRepository {
  final SupabaseClient supabase;
  final ReceiptParserService parserService;
  final TextRecognizer textRecognizer;

  ScannerRepositoryImpl({
    required this.supabase,
    required this.parserService,
    TextRecognizer? textRecognizer,
  }) : textRecognizer = textRecognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      return recognizedText.text;
    } catch (e) {
      throw Exception('Failed to extract text: $e');
    }
  }

  @override
  Future<ScannedReceipt> parseReceiptText(String rawText) async {
    try {
      return await parserService.parseReceipt(rawText);
    } catch (e) {
      throw Exception('Failed to parse receipt: $e');
    }
  }

  @override
  Future<ScannedReceipt> processReceiptImage(String imagePath) async {
    try {
      // Step 1: Extract text from image
      final rawText = await extractTextFromImage(imagePath);

      // Step 2: Parse extracted text into structured receipt data
      final receipt = await parseReceiptText(rawText);

      // Step 3: Save debug log (if in debug mode)
      if (kDebugMode) {
        await saveOcrDebugLog(
          rawText: rawText,
          merchant: receipt.merchantName,
          total: receipt.totalAmount,
          tax: receipt.taxAmount,
        );
      }

      return receipt;
    } catch (e) {
      throw Exception('Failed to process receipt image: $e');
    }
  }

  @override
  Future<void> saveOcrDebugLog({
    required String rawText,
    required String? merchant,
    required double? total,
    required double? tax,
  }) async {
    try {
      await supabase.from('ocr_debug_logs').insert({
        'raw_text': rawText,
        'merchant': merchant,
        'total': total,
        'tax': tax,
        'scan_date': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Log failures silently — debug logging shouldn't crash the app
      debugPrint('Failed to save OCR debug log: $e');
    }
  }
}
