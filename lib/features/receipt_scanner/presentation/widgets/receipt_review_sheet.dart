import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/receipt_scan_result.dart';

/// Bottom sheet that previews what was parsed from the receipt
/// and lets the user confirm before fields are filled in.
class ReceiptReviewSheet extends StatelessWidget {
  const ReceiptReviewSheet({super.key, required this.result});

  final ReceiptScanResult result;

  static Future<bool> show(
    BuildContext context,
    ReceiptScanResult result,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReceiptReviewSheet(result: result),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 20),
                const SizedBox(width: 8),
                Text('Receipt Data Found', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Review and tap "Use These Values" to fill the form.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            _Row(
              icon: Icons.store_outlined,
              label: 'Merchant',
              value: result.merchant ?? '—',
              found: result.merchant != null,
            ),
            const Divider(height: 24),
            _Row(
              icon: Icons.attach_money,
              label: 'Total',
              value: result.total != null
                  ? CurrencyFormatter.format(result.total!)
                  : '—',
              found: result.total != null,
            ),
            const Divider(height: 24),
            _Row(
              icon: Icons.receipt_outlined,
              label: 'Tax / VAT / GST',
              value: result.tax != null
                  ? CurrencyFormatter.format(result.tax!)
                  : '—',
              found: result.tax != null,
            ),
            const Divider(height: 24),
            _Row(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: result.date != null
                  ? DateFormatter.toDisplay(result.date!)
                  : '—',
              found: result.date != null,
            ),
            const SizedBox(height: 20),
            // Raw OCR debug panel — lets the user copy the exact text the
            // OCR engine produced so parsing issues can be diagnosed.
            _RawOcrPanel(rawText: result.rawText),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Discard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Use These Values'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RawOcrPanel extends StatefulWidget {
  const _RawOcrPanel({required this.rawText});
  final String rawText;

  @override
  State<_RawOcrPanel> createState() => _RawOcrPanelState();
}

class _RawOcrPanelState extends State<_RawOcrPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
                Text(
                  'Raw OCR text (tap to copy & share for debugging)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  widget.rawText.isEmpty ? '(no text recognised)' : widget.rawText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.rawText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Raw OCR text copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    required this.found,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool found;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade500)),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: found ? null : Colors.grey.shade400,
                      fontWeight:
                          found ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ],
          ),
        ),
        if (found)
          const Icon(Icons.check_circle_outline,
              size: 18, color: Colors.green)
        else
          Icon(Icons.help_outline, size: 18, color: Colors.grey.shade400),
      ],
    );
  }
}
