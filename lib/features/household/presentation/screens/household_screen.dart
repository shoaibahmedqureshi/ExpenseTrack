import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../expense_split/domain/split_calculator.dart';
import '../../domain/household_calculator.dart';
import '../../domain/household_models.dart';
import '../providers/household_provider.dart';

/// How the family is doing against its monthly budget, built from totals that members chose to share.
class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key, required this.familyId});
  final int familyId;

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<HouseholdProvider>();
      p.load(widget.familyId).then((_) => p.publishNow());
    });
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  String _money(int cents) => CurrencyFormatter.format(cents / 100);

  Future<void> _editBudget(HouseholdProvider p, {String? category, int? current}) async {
    final result = await showDialog<_BudgetResult>(
      context: context,
      builder: (_) => _BudgetDialog(title: category == null ? 'Monthly household budget' : '$category budget', currentCents: current),
    );
    if (result == null || !mounted) return;
    final ok = result.remove ? await p.clearBudget(category) : await p.setBudget(category, result.cents!);
    if (!mounted) return;
    _snack(ok ? (result.remove ? 'Budget removed' : 'Budget saved') : (p.error ?? 'Could not save the budget'));
  }

  Future<void> _addCategoryBudget(HouseholdProvider p, List<String> suggestions) async {
    final name = await showDialog<String>(context: context, builder: (_) => _CategoryPickDialog(suggestions: suggestions));
    if (name == null || !mounted) return;
    await _editBudget(p, category: name);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<HouseholdProvider>();
    final o = p.overview;
    final overall = HouseholdCalculator.overall(o);
    final lines = HouseholdCalculator.categoryLines(o);
    final me = p.me;

    return Scaffold(
      appBar: AppBar(title: const Text('Household budget', style: TextStyle(fontWeight: FontWeight.w800))),
      body: !p.hasLoaded && p.isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor)))
          : RefreshIndicator(
              onRefresh: () => p.load(widget.familyId).then((_) => p.publishNow()),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  if (p.error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: Text(p.error!, style: const TextStyle(color: Colors.red)),
                    ),
                  _monthRow(p),
                  const SizedBox(height: 8),
                  _budgetCard(p, overall),
                  const SizedBox(height: 12),
                  _sharingCard(p, me),
                  if (lines.isNotEmpty || (p.isOwner)) ...[
                    _title('By category'),
                    for (final l in lines) _categoryTile(p, l),
                    if (p.isOwner)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _addCategoryBudget(p, [for (final l in lines) l.category]),
                          icon: const Icon(Icons.add),
                          label: const Text('Add a category budget'),
                        ),
                      ),
                  ],
                  _title('Members'),
                  for (final m in o.members) _memberTile(m, p.getCurrentUserId()),
                  if (HouseholdCalculator.notSharingCount(o) > 0 && o.members.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Only people who share their monthly totals are counted. Nobody ever sees another person\'s individual expenses.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );

  Widget _monthRow(HouseholdProvider p) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), tooltip: 'Previous month', onPressed: p.previousMonth),
          Text(DateFormat.yMMMM().format(p.month), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          IconButton(icon: const Icon(Icons.chevron_right), tooltip: 'Next month', onPressed: p.canGoForward ? p.nextMonth : null),
        ],
      );

  Widget _budgetCard(HouseholdProvider p, BudgetStatus? s) {
    final spent = HouseholdCalculator.totalCents(p.overview);
    final over = s?.isOver ?? false;
    final color = over ? Colors.red.shade700 : AppTheme.primaryColor;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Household spending', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(_money(spent), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color)),
        if (s != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: s.fraction, minHeight: 8, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(color)),
          ),
          const SizedBox(height: 8),
          Text(
            over ? '${_money(-s.remainingCents)} over the ${_money(s.budgetCents)} budget' : '${_money(s.remainingCents)} left of ${_money(s.budgetCents)} (${s.percentUsed}% used)',
            style: TextStyle(color: over ? Colors.red.shade700 : AppTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('No monthly budget set yet', style: TextStyle(color: AppTheme.textSecondary)),
          ),
        if (p.isOwner)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: p.isBusy ? null : () => _editBudget(p, current: s?.budgetCents),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(s == null ? 'Set monthly budget' : 'Change budget'),
            ),
          ),
      ]),
    );
  }

  Widget _sharingCard(HouseholdProvider p, HouseholdMember? me) {
    final on = me?.sharing ?? false;
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        value: on,
        onChanged: (me == null || p.isBusy)
            ? null
            : (v) async {
                final ok = await p.setSharing(v);
                if (!mounted) return;
                _snack(ok ? (v ? 'Sharing is on' : 'Sharing is off. Your totals were removed.') : (p.error ?? 'Could not change sharing'));
              },
        title: const Text('Share my monthly totals', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text(
          'Your family sees how much you spent per category each month, never individual expenses. Off by default. Turning it off removes what you shared.',
        ),
      ),
    );
  }

  Widget _categoryTile(HouseholdProvider p, CategoryLine l) {
    final s = l.status;
    final over = s?.isOver ?? false;
    final color = over ? Colors.red.shade700 : AppTheme.primaryColor;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: p.isOwner ? () => _editBudget(p, category: l.category, current: l.budgetCents) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(l.category, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(s == null ? _money(l.spentCents) : '${_money(l.spentCents)} of ${_money(s.budgetCents)}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: over ? color : null)),
            ]),
            if (s != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: s.fraction, minHeight: 6, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(color)),
              ),
              if (over)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${_money(-s.remainingCents)} over', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _memberTile(HouseholdMember m, String me) {
    final who = m.userId == me ? 'You' : (m.name.isNotEmpty ? m.name : m.email.split('@').first);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(who.isEmpty ? '?' : who[0].toUpperCase())),
      title: Text(who + (m.isOwner ? ' · Admin' : '')),
      subtitle: Text(m.sharing ? 'Sharing monthly totals' : 'Not sharing'),
      trailing: m.sharing ? Text(_money(m.totalCents), style: const TextStyle(fontWeight: FontWeight.w800)) : const Icon(Icons.visibility_off_outlined, size: 18, color: AppTheme.textSecondary),
    );
  }
}

class _BudgetResult {
  const _BudgetResult.save(this.cents) : remove = false;
  const _BudgetResult.remove()
      : cents = null,
        remove = true;
  final int? cents;
  final bool remove;
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({required this.title, this.currentCents});
  final String title;
  final int? currentCents;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.currentCents == null ? '' : (widget.currentCents! / 100).toStringAsFixed(2));
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final cents = SplitCalculator.toCents(_c.text);
    if (cents == null || cents <= 0) {
      setState(() => _error = 'Enter an amount greater than zero');
      return;
    }
    Navigator.pop(context, _BudgetResult.save(cents));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Amount per month', prefixText: '\$ ', errorText: _error, border: const OutlineInputBorder()),
          onSubmitted: (_) => _save(),
        ),
        actions: [
          if (widget.currentCents != null)
            TextButton(onPressed: () => Navigator.pop(context, const _BudgetResult.remove()), child: const Text('Remove', style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      );
}

/// Pick a category (from the household's spending) or type a new name for a category budget.
class _CategoryPickDialog extends StatefulWidget {
  const _CategoryPickDialog({required this.suggestions});
  final List<String> suggestions;

  @override
  State<_CategoryPickDialog> createState() => _CategoryPickDialogState();
}

class _CategoryPickDialogState extends State<_CategoryPickDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _done(String s) {
    final t = s.trim();
    if (t.isNotEmpty && t.length <= 40) Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Category budget'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.suggestions.isNotEmpty)
            Wrap(spacing: 8, children: [for (final s in widget.suggestions) ActionChip(label: Text(s), onPressed: () => _done(s))]),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Or type a category name', border: OutlineInputBorder()),
            onSubmitted: _done,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => _done(_c.text), child: const Text('Next')),
        ],
      );
}
