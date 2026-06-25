import 'package:flutter/material.dart';
import '../../data/receipt_scanner_service.dart';
import '../../domain/receipt_scan_result.dart';

class ScanReceiptButton extends StatefulWidget {
  const ScanReceiptButton({super.key, required this.onScanned});

  final void Function(ReceiptScanResult result) onScanned;

  @override
  State<ScanReceiptButton> createState() => _ScanReceiptButtonState();
}

class _ScanReceiptButtonState extends State<ScanReceiptButton> {
  bool _scanning = false;

  // sheetContext is the BuildContext of the bottom sheet itself,
  // so Navigator.pop closes the sheet and not the parent route.
  Future<void> _startScan(BuildContext sheetContext, ScanSource source) async {
    Navigator.pop(sheetContext);
    setState(() => _scanning = true);
    try {
      final result = await ReceiptScannerService.instance.scan(source);
      if (!mounted) return;
      if (result == null) return; // user cancelled
      if (!result.hasAnyData) {
        _showSnack('Could not read receipt data. Try a clearer photo.');
      } else {
        widget.onScanned(result);
      }
    } catch (e) {
      if (mounted) _showSnack('Scan failed: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _showSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text('Scan Receipt',
                  style: Theme.of(sheetCtx).textTheme.titleMedium),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.camera_alt)),
                title: const Text('Take a photo'),
                subtitle: const Text('Open camera'),
                onTap: () => _startScan(sheetCtx, ScanSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.photo_library)),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Pick an existing photo'),
                onTap: () => _startScan(sheetCtx, ScanSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _scanning ? null : _showSourceSheet,
      icon: _scanning
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.document_scanner_outlined),
      label: Text(_scanning ? 'Scanning…' : 'Scan Receipt'),
    );
  }
}
