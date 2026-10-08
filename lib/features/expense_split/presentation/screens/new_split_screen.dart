import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../family_accounts/presentation/providers/family_provider.dart';
import '../../domain/split_calculator.dart';
import '../../domain/split_models.dart';
import '../member_names.dart';
import '../providers/expense_split_provider.dart';

class NewSplitScreen extends StatefulWidget {
  const NewSplitScreen({super.key, required this.members});

  /// The people in the family or group the split belongs to.
  final List<LedgerMember> members;

  @override
  State<NewSplitScreen> createState() => _NewSplitScreenState();
}

class _NewSplitScreenState extends State<NewSplitScreen> {
  final _description = TextEditingController();
  final _total = TextEditingController();
  final _amounts = <String, TextEditingController>{};
  final _percents = <String, TextEditingController>{};
  late final Set<String> _included;
  late String _payer;
  SplitType _type = SplitType.equal;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final me = context.read<FamilyProvider>().getCurrentUserId();
    final ids = widget.members.map((m) => m.userId).toList();
    _included = {...ids};
    _payer = ids.contains(me) ? me : (ids.isNotEmpty ? ids.first : me);
    for (final id in ids) {
      _amounts[id] = TextEditingController();
      _percents[id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _total.dispose();
    for (final c in [..._amounts.values, ..._percents.values]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _memberIds => _amounts.keys.toList();
  int? get _totalCents => SplitCalculator.toCents(_total.text);

  Map<String, int> _equal() {
    final t = _totalCents;
    final chosen = _memberIds.where(_included.contains).toList();
    return t == null ? {} : SplitCalculator.equalShares(t, chosen);
  }

  /// Parses a field: empty counts as zero, junk is reported as null.
  int? _fieldCents(String id) {
    final text = _amounts[id]!.text.trim();
    return text.isEmpty ? 0 : SplitCalculator.toCents(text);
  }

  double? _fieldPercent(String id) {
    final text = _percents[id]!.text.trim();
    if (text.isEmpty) return 0;
    final v = double.tryParse(text);
    return (v == null || v < 0 || v > 100) ? null : v;
  }

  /// The shares the current inputs would produce, or an error message.
  ({Map<String, int>? shares, Map<String, double>? percents, String? error}) _compute() {
    final total = _totalCents;
    if (total == null || total <= 0) {
      return (shares: null, percents: null, error: 'Enter a total amount greater than zero');
    }
    switch (_type) {
      case SplitType.equal:
        final s = _equal();
        final err = SplitCalculator.validateAmountShares(total, s);
        return (shares: err == null ? s : null, percents: null, error: err);
      case SplitType.amount:
        final s = <String, int>{};
        for (final id in _memberIds) {
          final c = _fieldCents(id);
          if (c == null) {
            return (shares: null, percents: null, error: 'Check the amounts: use numbers with up to 2 decimals');
          }
          if (c > 0) s[id] = c;
        }
        final err = SplitCalculator.validateAmountShares(total, s);
        return (shares: err == null ? s : null, percents: null, error: err);
      case SplitType.percent:
        final p = <String, double>{};
        for (final id in _memberIds) {
          final v = _fieldPercent(id);
          if (v == null) {
            return (shares: null, percents: null, error: 'Percentages must be between 0 and 100');
          }
          if (v > 0) p[id] = v;
        }
        final sum = p.values.fold<double>(0, (a, b) => a + b);
        if (p.isEmpty) {
          return (shares: null, percents: null, error: 'Choose at least one person to split with');
        }
        if ((sum - 100).abs() > 0.005) {
          return (shares: null, percents: null,
              error: 'Percentages add up to ${_trim(sum)}%, they need to total 100%');
        }
        final s = SplitCalculator.percentShares(total, p)!;
        s.removeWhere((_, c) => c == 0);
        return (shares: s, percents: p, error: null);
    }
  }

  String _trim(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  void _fillEqually() {
    final ids = _memberIds;
    if (ids.isEmpty) return;
    if (_type == SplitType.amount) {
      final t = _totalCents;
      if (t == null || t <= 0) return;
      final eq = SplitCalculator.equalShares(t, ids);
      for (final id in ids) {
        _amounts[id]!.text = (eq[id]! / 100).toStringAsFixed(2);
      }
    } else if (_type == SplitType.percent) {
      final base = (10000 ~/ ids.length) / 100;
      var rest = 100 - base * ids.length;
      for (var i = 0; i < ids.length; i++) {
        final v = i == 0 ? base + rest : base;
        _percents[ids[i]]!.text = _trim(double.parse(v.toStringAsFixed(2)));
      }
    }
    setState(() {});
  }

  Future<void> _save() async {
    final desc = _description.text.trim();
    if (desc.isEmpty) {
      setState(() => _error = 'Add a short description, e.g. "Groceries"');
      return;
    }
    final r = _compute();
    if (r.error != null) {
      setState(() => _error = r.error);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final provider = context.read<ExpenseSplitProvider>();
    final ok = await provider.createSplit(
      paidBy: _payer,
      description: desc,
      totalCents: _totalCents!,
      type: _type,
      sharesCents: r.shares!,
      percents: r.percents,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = provider.error ?? 'Could not save the split';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = MemberNames(widget.members, context.read<FamilyProvider>().getCurrentUserId());
    final r = _compute();

    return Scaffold(
      appBar: AppBar(title: const Text('New split', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(
            controller: _description,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'What was it for?', hintText: 'Groceries, dinner, rent…', border: OutlineInputBorder(), counterText: ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _total,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Total amount', prefixText: '\$ ', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _memberIds.contains(_payer) ? _payer : null,
            decoration: const InputDecoration(labelText: 'Paid by', border: OutlineInputBorder()),
            items: [for (final id in _memberIds) DropdownMenuItem(value: id, child: Text(names.of(id)))],
            onChanged: _saving ? null : (v) => setState(() => _payer = v ?? _payer),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<SplitType>(
              segments: [for (final t in SplitType.values) ButtonSegment(value: t, label: Text(t == SplitType.percent ? 'By %' : t.label, style: const TextStyle(fontSize: 12)))],
              selected: {_type},
              onSelectionChanged: _saving ? null : (s) => setState(() => _type = s.first),
            ),
          ),
          const SizedBox(height: 8),
          if (_type != SplitType.equal)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _saving ? null : _fillEqually,
                icon: const Icon(Icons.balance, size: 18),
                label: const Text('Fill equally'),
              ),
            ),
          for (final id in _memberIds) _memberRow(id, names, r.shares),
          const SizedBox(height: 8),
          _summary(r),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save split'),
          ),
        ],
      ),
    );
  }

  Widget _memberRow(String id, MemberNames names, Map<String, int>? shares) {
    final label = Text(names.of(id), style: const TextStyle(fontWeight: FontWeight.w600));
    switch (_type) {
      case SplitType.equal:
        final share = _equal()[id];
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _included.contains(id),
          onChanged: _saving ? null : (v) => setState(() => v == true ? _included.add(id) : _included.remove(id)),
          title: label,
          secondary: Text(share == null || !_included.contains(id) ? '' : CurrencyFormatter.format(share / 100),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          controlAffinity: ListTileControlAffinity.leading,
        );
      case SplitType.amount:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: label),
            SizedBox(
              width: 130,
              child: TextField(
                controller: _amounts[id],
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.end,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(prefixText: '\$ ', hintText: '0.00', isDense: true, border: OutlineInputBorder()),
              ),
            ),
          ]),
        );
      case SplitType.percent:
        final p = _fieldPercent(id);
        final cents = (shares != null && shares[id] != null) ? shares[id]! : null;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: label),
            if (cents != null && (p ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(CurrencyFormatter.format(cents / 100), style: const TextStyle(color: AppTheme.textSecondary)),
              ),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _percents[id],
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.end,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(suffixText: ' %', hintText: '0', isDense: true, border: OutlineInputBorder()),
              ),
            ),
          ]),
        );
    }
  }

  Widget _summary(({Map<String, int>? shares, Map<String, double>? percents, String? error}) r) {
    final total = _totalCents ?? 0;
    String text;
    var ok = false;
    switch (_type) {
      case SplitType.equal:
        final n = _included.length;
        text = n == 0 ? 'Select who to split with' : 'Splitting between $n ${n == 1 ? 'person' : 'people'}';
        ok = r.error == null;
      case SplitType.amount:
        var sum = 0;
        for (final id in _memberIds) {
          sum += _fieldCents(id) ?? 0;
        }
        final left = total - sum;
        text = left == 0 && total > 0
            ? 'All ${CurrencyFormatter.format(total / 100)} assigned'
            : '${CurrencyFormatter.format(left.abs() / 100)} ${left >= 0 ? 'left to assign' : 'over the total'}';
        ok = left == 0 && total > 0;
      case SplitType.percent:
        var sum = 0.0;
        for (final id in _memberIds) {
          sum += _fieldPercent(id) ?? 0;
        }
        text = '${_trim(sum)}% of 100% assigned';
        ok = (sum - 100).abs() <= 0.005;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (ok ? AppTheme.primaryColor : Colors.orange).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(ok ? Icons.check_circle : Icons.info_outline, size: 18, color: ok ? AppTheme.primaryColor : Colors.orange),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
