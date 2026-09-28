import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'image_picker_service.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/scanner_provider.dart';
import 'receipt_preview_screen.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Consumer<ScannerProvider>(
        builder: (context, scannerProvider, _) {
          // If we have a scanned receipt, show preview
          if (scannerProvider.lastReceipt != null) {
            return ReceiptPreviewScreen(
              receipt: scannerProvider.lastReceipt!,
              onRetake: () => scannerProvider.clearReceipt(),
            );
          }

          // Otherwise show camera/upload options
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    size: 60,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Scan a Receipt',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Take a photo or upload an image of a receipt to extract details automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (scannerProvider.isProcessing)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                    ),
                  )
                else ...[
                  SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      onPressed: () => _takePhoto(context, scannerProvider),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 200,
                    child: OutlinedButton.icon(
                      onPressed: () => _uploadPhoto(context, scannerProvider),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Upload Image'),
                    ),
                  ),
                ],
                if (scannerProvider.error != null) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.expenseColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        scannerProvider.error!,
                        style: const TextStyle(
                          color: AppTheme.expenseColor,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _takePhoto(BuildContext context, ScannerProvider scannerProvider) async {
    final imagePath = await ImagePickerService.takePhoto(context);
    if (imagePath != null) {
      await scannerProvider.scanReceipt(imagePath);
    }
  }

  void _uploadPhoto(BuildContext context, ScannerProvider scannerProvider) async {
    final imagePath = await ImagePickerService.pickFromGallery(context);
    if (imagePath != null) {
      await scannerProvider.scanReceipt(imagePath);
    }
  }
}
