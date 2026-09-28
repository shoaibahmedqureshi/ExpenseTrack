import 'package:flutter/material.dart';

import '../../domain/entities/scanned_receipt.dart';
import '../../domain/repositories/scanner_repository.dart';

class ScannerProvider extends ChangeNotifier {
  final ScannerRepository repository;

  ScannedReceipt? _lastReceipt;
  bool _isProcessing = false;
  String? _error;
  double _confidence = 0.0;

  ScannerProvider({required this.repository});

  ScannedReceipt? get lastReceipt => _lastReceipt;
  bool get isProcessing => _isProcessing;
  String? get error => _error;
  double get confidence => _confidence;

  /// Process an image file from camera/gallery
  Future<bool> scanReceipt(String imagePath) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      _lastReceipt = await repository.processReceiptImage(imagePath);
      _confidence = _lastReceipt?.confidence ?? 0.0;
      _isProcessing = false;
      notifyListeners();
      return _lastReceipt?.isValid ?? false;
    } catch (e) {
      _error = e.toString();
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear the current receipt
  void clearReceipt() {
    _lastReceipt = null;
    _confidence = 0.0;
    _error = null;
    notifyListeners();
  }

  /// Confirm receipt and prepare for expense creation
  ScannedReceipt? getConfirmedReceipt() {
    return (_lastReceipt?.isValid ?? false) ? _lastReceipt : null;
  }
}
