import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/scanned_receipt.dart';

class ReceiptPreviewScreen extends StatelessWidget {
  final ScannedReceipt receipt;
  final VoidCallback onRetake;
  final VoidCallback? onConfirm;

  const ReceiptPreviewScreen({
    super.key,
    required this.receipt,
    required this.onRetake,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Receipt Details Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Merchant
                  _buildField('Merchant', receipt.merchantName ?? 'Unknown'),
                  const SizedBox(height: 16),

                  // Date
                  if (receipt.transactionDate != null)
                    _buildField(
                      'Date',
                      DateFormat.yMMMMd().format(receipt.transactionDate!),
                    )
                  else
                    _buildField('Date', 'Not detected'),
                  const SizedBox(height: 16),

                  // Amount
                  _buildField(
                    'Total',
                    receipt.totalAmount != null
                        ? CurrencyFormatter.format(receipt.totalAmount!)
                        : 'Not detected',
                    highlight: receipt.totalAmount != null,
                  ),
                  const SizedBox(height: 12),

                  // Tax
                  if (receipt.taxAmount != null)
                    _buildField(
                      'Tax',
                      CurrencyFormatter.format(receipt.taxAmount!),
                    ),

                  // Confidence
                  const SizedBox(height: 16),
                  _buildConfidenceBadge(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Line Items
          if (receipt.lineItems != null && receipt.lineItems!.isNotEmpty) ...[
            Text(
              'Items (${receipt.lineItems!.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: receipt.lineItems!.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.description,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.quantity != 1)
                                  Text(
                                    'Qty: ${item.quantity}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(item.totalPrice),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Raw text preview
          if (receipt.rawText != null && receipt.rawText!.isNotEmpty) ...[
            ExpansionTile(
              title: const Text('Raw OCR Text'),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    receipt.rawText!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Courier',
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 20,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRetake,
                  icon: const Icon(Icons.replay),
                  label: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: receipt.isValid ? onConfirm : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!receipt.isValid)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.expenseColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Receipt not valid. Please retake with a clearer image.',
                style: TextStyle(
                  color: AppTheme.expenseColor,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 18 : 15,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceBadge() {
    final color = receipt.confidence >= 0.8
        ? AppTheme.incomeColor
        : receipt.confidence >= 0.6
            ? const Color(0xFFF59E0B)
            : AppTheme.expenseColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            receipt.confidence >= 0.8
                ? Icons.check_circle
                : Icons.info,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            'Confidence: ${(receipt.confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
