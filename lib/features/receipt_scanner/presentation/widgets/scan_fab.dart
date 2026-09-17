import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/review_prompt.dart';
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
  bool _overlayShowing = false;

  Future<void> _scan(ScanSource source) async {
    if (_scanning) return;

    final svc = context.read<SubscriptionService>();
    // Soft, non-consuming check — the real, quota-consuming check happens
    // in tryIncrementScan() below, only once the user actually keeps a
    // scan. This local-cache read can be briefly stale (e.g. a scan just
    // done on another device) but that's an acceptable gap for a pre-flight
    // gate; it isn't the enforcement point.
    if (!svc.status.canScan) {
      _showLimitSheet();
      return;
    }

    setState(() => _scanning = true);
    // Covers the gap between the native scanner activity closing and the
    // review sheet appearing (image normalization + on-device OCR, which
    // can genuinely take a few seconds) with a visible loading state,
    // rather than leaving whatever was behind the FAB on screen with only
    // the small in-FAB spinner as feedback.
    _showScanningOverlay();
    try {
      final result = await ReceiptScannerService.instance.scan(source);
      _hideScanningOverlay();
      if (!mounted || result == null) return;

      if (!result.hasAnyData) {
        _showSnack('Could not read receipt data. Try a clearer photo.');
        _openForm(null);
        return;
      }

      final confirmed = await ReceiptReviewSheet.show(context, result);
      if (!mounted) return;

      // Only spend a scan credit once the user has actually kept the
      // result — a receipt OCR couldn't read, or one the user discarded,
      // shouldn't cost anything.
      if (confirmed) {
        await svc.tryIncrementScan();
        unawaited(ReviewPrompt.onSuccessfulScan());
      }
      _openForm(confirmed ? result : null);
    } catch (e) {
      _hideScanningOverlay();
      if (mounted) _showSnack('Scan failed: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _showScanningOverlay() {
    _overlayShowing = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: _ScanningOverlay(),
      ),
    ).then((_) => _overlayShowing = false);
  }

  void _hideScanningOverlay() {
    if (_overlayShowing && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
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
              const _ScanTips(),
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
    // Plain circular FAB rather than extended/pill-shaped: this docks into
    // a notch cut into the bottom nav bar (see MainShell), and
    // CircularNotchedRectangle's notch geometry assumes a roughly round
    // FAB — a wide extended button wouldn't sit in it cleanly. Deliberately
    // keeps this shape and the centered/docked position even though the
    // Stitch reference design shows a rounded-square FAB floating at
    // bottom-right — matching that would fight the notch and was
    // explicitly excluded from this restyle (position/shape stay as-is,
    // only the icon glyph and color come from the reference).
    return FloatingActionButton(
      onPressed: _scanning ? null : _showSourceSheet,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      child: _scanning
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
          : const Icon(Icons.qr_code_scanner),
    );
  }
}

/// Blocking loading state shown from the moment a scan starts until either
/// the review sheet is ready or an error/empty result is handled — covers
/// the native-scanner-return + on-device-OCR gap that otherwise has no
/// visible feedback beyond the small spinner inside the FAB itself.
class _ScanningOverlay extends StatelessWidget {
  const _ScanningOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text('Reading receipt…', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Capture tips shown before the camera opens. OCR accuracy depends far
/// more on the photo than on parsing: a flat, well-lit, fully-framed
/// receipt reads near-perfectly, while shadows and skew produce the
/// misreads no parser can fully recover from.
class _ScanTips extends StatelessWidget {
  const _ScanTips();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates_outlined,
              size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Best results: lay the receipt flat in good light, hold your '
              'phone 20–30 cm (8–12 in) above it so the text fills the '
              'frame, and keep it upright — not sideways.',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
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
