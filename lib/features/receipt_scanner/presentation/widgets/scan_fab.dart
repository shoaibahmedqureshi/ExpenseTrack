import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/receipt_scanner_service.dart';
import '../../domain/receipt_scan_result.dart';
import 'receipt_review_sheet.dart';
import '../../../expenses/presentation/screens/add_expense_screen.dart';
import '../../../subscription/data/subscription_service.dart';
import '../../../subscription/domain/subscription_status.dart';
import '../../../subscription/presentation/screens/paywall_screen.dart';

class ScanFab extends StatefulWidget {
  const ScanFab({super.key});

  @override
  State<ScanFab> createState() => _ScanFabState();
}

class _ScanFabState extends State<ScanFab> {
  bool _scanning = false;

  Future<void> _scan(ScanSource source) async {
    if (_scanning) return;

    final svc = context.read<SubscriptionService>();
    final allowed = await svc.tryIncrementScan();
    if (!allowed && mounted) {
      _showLimitSheet();
      return;
    }

    setState(() => _scanning = true);
    try {
      final result = await ReceiptScannerService.instance.scan(source);
      if (!mounted || result == null) return;

      if (!result.hasAnyData) {
        _showSnack('Could not read receipt data. Try a clearer photo.');
        _openForm(null);
        return;
      }

      final confirmed = await ReceiptReviewSheet.show(context, result);
      if (!mounted) return;
      _openForm(confirmed ? result : null);
    } catch (e) {
      if (mounted) _showSnack('Scan failed: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _openForm(ReceiptScanResult? prefill) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddExpenseScreen(prefill: prefill)),
    );
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _showLimitSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F0F1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(Icons.lock_outline, color: Color(0xFFFFD700), size: 48),
            const SizedBox(height: 16),
            const Text('Monthly Limit Reached',
                style: TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'You\'ve used all ${SubscriptionStatus.freeScansPerMonth} free scans '
              'for this month. Upgrade to Pro for unlimited scanning.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  PaywallScreen.show(context);
                },
                icon: const Icon(Icons.workspace_premium),
                label: const Text('Upgrade to Pro',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () { Navigator.pop(ctx); _openForm(null); },
              child: const Text('Enter manually instead',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSourceSheet() {
    final status = context.read<SubscriptionService>().status;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Scan Receipt',
                      style: Theme.of(sheetCtx).textTheme.titleMedium),
                  if (!status.isPro) ...[
                    const SizedBox(width: 8),
                    _ScanBadge(remaining: status.scansRemaining),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                status.isPro ? 'Unlimited scans — Pro plan' : 'Choose image source',
                style: Theme.of(sheetCtx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.camera_alt)),
                title: const Text('Take a photo'),
                subtitle: const Text('Open camera'),
                onTap: () { Navigator.pop(sheetCtx); _scan(ScanSource.camera); },
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.photo_library)),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Pick an existing photo'),
                onTap: () { Navigator.pop(sheetCtx); _scan(ScanSource.gallery); },
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.edit_outlined, color: Colors.white),
                ),
                title: const Text('Enter manually'),
                subtitle: const Text('Fill in details yourself'),
                onTap: () { Navigator.pop(sheetCtx); _openForm(null); },
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
    return FloatingActionButton.extended(
      onPressed: _scanning ? null : _showSourceSheet,
      icon: _scanning
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
          : const Icon(Icons.document_scanner_outlined),
      label: Text(_scanning ? 'Scanning…' : 'Scan Receipt'),
    );
  }
}

class _ScanBadge extends StatelessWidget {
  const _ScanBadge({required this.remaining});
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final isLow = remaining <= 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isLow ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$remaining left',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isLow ? Colors.red.shade700 : Colors.blue.shade700,
        ),
      ),
    );
  }
}
