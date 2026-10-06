import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../providers/import_provider.dart';

class ImportPreviewView extends StatelessWidget {
  const ImportPreviewView({super.key, required this.provider, required this.onImport});

  final ImportProvider provider;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final s = provider.statement!;
    final df = DateFormat.yMMMd();
    final n = provider.selectedCount;
    return Column(children: [
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          itemCount: provider.rows.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) return _summary(s, df);
            return _row(context, i - 1);
          },
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: n == 0 ? null : onImport,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text(n == 0 ? 'Select transactions to import' : 'Import $n transaction${n == 1 ? '' : 's'}'),
          ),
        ),
      ),
    ]);
  }

  Widget _summary(dynamic s, DateFormat df) {
    final total = provider.rows.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.bankName}${s.accountNumber.isEmpty ? '' : '  ${s.accountNumber}'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${df.format(s.periodStart)} – ${df.format(s.periodEnd)} · $total ${total == 1 ? 'transaction' : 'transactions'}'
                  '${provider.skippedRows > 0 ? ' · ${provider.skippedRows} non-transaction ${provider.skippedRows == 1 ? 'line' : 'lines'} ignored' : ''}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _total('Money out', provider.selectedExpenseTotal, Colors.red.shade700)),
                Expanded(child: _total('Money in', provider.selectedIncomeTotal, Colors.green.shade700)),
              ]),
              if (provider.duplicateCount > 0) ...[
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.content_copy, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('${provider.duplicateCount} look like transactions you already recorded and are unticked.',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ]),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text('${provider.selectedCount} of $total selected',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton(onPressed: () => provider.setAll(true), child: const Text('All')),
          TextButton(onPressed: () => provider.setAll(false), child: const Text('None')),
        ]),
      ]),
    );
  }

  Widget _total(String label, double v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        Text(CurrencyFormatter.format(v), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c)),
      ]);

  Widget _row(BuildContext context, int i) {
    final r = provider.rows[i];
    final t = r.txn;
    final df = DateFormat.MMMd();
    final color = t.isExpense ? Colors.red.shade700 : Colors.green.shade700;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: r.selected ? null : Colors.grey.withOpacity(0.08),
      child: InkWell(
        onTap: () => provider.toggle(i),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(value: r.selected, onChanged: (_) => provider.toggle(i)),
            Expanded(
              child: Opacity(
                opacity: r.selected ? 1 : 0.55,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(df.format(t.date), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  if (r.duplicateNote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(r.duplicateNote!, style: const TextStyle(color: Colors.orange, fontSize: 12)),
                    ),
                  const SizedBox(height: 6),
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.label_outline, size: 16),
                    label: Text(r.category, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _pickCategory(context, i),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Text('${t.isExpense ? '−' : '+'}${CurrencyFormatter.format(t.amount)}',
                style: TextStyle(fontWeight: FontWeight.w800, color: r.selected ? color : AppTheme.textSecondary)),
          ]),
        ),
      ),
    );
  }

  void _pickCategory(BuildContext context, int i) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final name in provider.categoryNames)
            ListTile(
              title: Text(name),
              trailing: name == provider.rows[i].category ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
              onTap: () {
                provider.setCategory(i, name);
                Navigator.pop(ctx);
              },
            ),
        ]),
      ),
    );
  }
}
