import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../categories/domain/entities/category.dart' as cat;
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../receipt_scanner/domain/receipt_scan_result.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_provider.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, this.expense, this.prefill});

  /// Existing expense — when set, the screen is in edit mode.
  final Expense? expense;

  /// Pre-filled data from a receipt scan. Ignored when [expense] is set.
  final ReceiptScanResult? prefill;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late TransactionType _type;
  late DateTime _date;
  cat.Category? _category;

  bool get _isEditing => widget.expense != null;
  bool get _hasPrefill => widget.prefill != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    final p = widget.prefill;

    _type = e?.type ?? TransactionType.expense;
    _date = e?.date ?? p?.date ?? DateTime.now();
    _category = e?.category;
    _titleCtrl.text = e?.title ?? p?.merchant ?? '';
    _amountCtrl.text = e != null
        ? e.amount.toString()
        : p?.total != null
            ? p!.total!.toStringAsFixed(2)
            : '';
    _noteCtrl.text = e?.note ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final expense = Expense(
      id: widget.expense?.id,
      title: _titleCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text.trim()),
      date: _date,
      type: _type,
      category: _category!,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    final provider = context.read<ExpenseProvider>();
    if (_isEditing) {
      await provider.edit(expense);
    } else {
      await provider.add(expense);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Prefill notice ────────────────────────────────────────
            if (_hasPrefill && !_isEditing)
              _PrefillBanner(prefill: widget.prefill!),

            const SizedBox(height: 16),

            // ── Income / Expense toggle ───────────────────────────────
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v.trim()) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Category picker ───────────────────────────────────────
            Consumer<CategoryProvider>(
              builder: (context, catProvider, _) {
                // _category may hold a Category instance from the tapped
                // Expense (a different object than the provider's list even
                // when it represents the same row), so resolve the dropdown
                // value by id rather than relying on identity equality.
                cat.Category? value;
                for (final c in catProvider.categories) {
                  if (c.id == _category?.id) {
                    value = c;
                    break;
                  }
                }
                return DropdownButtonFormField<cat.Category>(
                  value: value,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: catProvider.categories
                      .map((c) => DropdownMenuItem<cat.Category>(
                            value: c,
                            child: Row(
                              children: [
                                Icon(c.icon, color: c.color, size: 20),
                                const SizedBox(width: 8),
                                Text(c.name),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (c) => setState(() => _category = c),
                  validator: (_) =>
                      _category == null ? 'Select a category' : null,
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Date picker ───────────────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormatter.toDisplay(_date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const Divider(),
            const SizedBox(height: 8),

            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _submit,
              child: Text(_isEditing ? 'Save Changes' : 'Add Transaction'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small banner shown when fields were pre-filled from a receipt scan.
class _PrefillBanner extends StatelessWidget {
  const _PrefillBanner({required this.prefill});

  final ReceiptScanResult prefill;

  @override
  Widget build(BuildContext context) {
    final filled = [
      if (prefill.merchant != null) 'title',
      if (prefill.total != null) 'amount',
      if (prefill.date != null) 'date',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              color: Colors.green.shade600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Receipt scanned — ${filled.join(', ')} pre-filled. Review and confirm.',
              style: TextStyle(
                  color: Colors.green.shade800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
