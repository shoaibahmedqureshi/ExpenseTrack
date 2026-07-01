import 'dart:developer' as dev;
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/receipt_scan_result.dart';
import 'receipt_parser.dart';

enum ScanSource { camera, gallery }

class ReceiptScannerService {
  ReceiptScannerService._();
  static final instance = ReceiptScannerService._();

  final _picker = ImagePicker();
  // Latin script covers most printed receipts; swap for ChineseScript etc. if needed.
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Returns null if the user cancels image selection.
  Future<ReceiptScanResult?> scan(ScanSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source == ScanSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1920,
    );
    if (file == null) return null;

    final inputImage = InputImage.fromFile(File(file.path));
    final recognized = await _recognizer.processImage(inputImage);
    dev.log('=== RAW OCR TEXT ===\n${recognized.text}\n=== END OCR ===',
        name: 'ReceiptScanner');
    return ReceiptParser.parse(recognized.text);
  }

  void dispose() => _recognizer.close();
}
