import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../expense_split/domain/split_calculator.dart';
import '../../../expense_split/domain/split_models.dart';
import '../../../expense_split/presentation/member_names.dart';
import '../../../expense_split/presentation/providers/expense_split_provider.dart';
import '../../../expense_split/presentation/screens/new_split_screen.dart';
import '../../../family_accounts/presentation/providers/family_provider.dart';
import '../../../split_groups/presentation/ledger_view.dart';
import '../../../split_groups/presentation/providers/split_group_provider.dart';
import '../../../split_groups/presentation/screens/group_detail_screen.dart';

class SplitsScreen extends StatelessWidget {
  const SplitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final view = watchLedgerView(context);
    ensureLedgerLoaded(context, view);
    final groups = context.watch<SplitGroupProvider>();
    final me = context.read<FamilyProvider>().getCurrentUserId();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Splits', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (view.isGroup)
            IconButton(
              icon: const Icon(Icons.group_outlined),
              tooltip: 'Group members',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: view.ledger!.id, myUserId: me)),
              ),
            ),
        ],
      ),
      body: view.ledger == null ? _noLedger(context, groups) : _content(context, view, groups, me),
    );
  }

  Future<void> _newGroup(BuildContext context) async {
    final name = await showDialog<String>(context: context, builder: (_) => const NameDialog());
    if (name == null || !context.mounted) return;
    final groups = context.read<SplitGroupProvider>();
    final sp = context.read<ExpenseSplitProvider>();
    final id = await groups.create(name);
    if (!context.mounted) return;
    if (id == null) {
      _snack(context, groups.error ?? 'Could not create the group');
      return;
    }
    final g = groups.byId(id);
    if (g != null) sp.load(g.ledger);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: id, myUserId: context.read<FamilyProvider>().getCurrentUserId())),
    );
  }

  Widget _invitations(BuildContext context, SplitGroupProvider groups) {
    if (groups.invitations.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      for (final i in groups.invitations)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: AppTheme.primaryColor.withOpacity(0.06),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Icon(Icons.mail_outline, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(child: Text('You are invited to "${i.groupName}"', style: const TextStyle(fontWeight: FontWeight.w600))),
              TextButton(
                onPressed: () async {
                  final ok = await groups.respond(i, false);
                  if (context.mounted && !ok) _snack(context, groups.error ?? 'Could not decline');
                },
                child: const Text('Decline'),
              ),
              FilledButton(
                onPressed: () async {
                  final ok = await groups.respond(i, true);
                  if (!context.mounted) return;
                  if (ok) {
                    final g = groups.groups.where((x) => x.id == i.groupId).firstOrNull;
                    if (g != null) context.read<ExpenseSplitProvider>().load(g.ledger);
                  }
                  _snack(context, ok ? 'You joined ${i.groupName}' : (groups.error ?? 'Could not join'));
                },
                child: const Text('Join'),
              ),
            ]),
          ),
        ),
    ]);
  }

  Widget _noLedger(BuildContext context, SplitGroupProvider groups) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _invitations(context, groups),
          const SizedBox(height: 40),
          Icon(Icons.groups_2_outlined, size: 64, color: AppTheme.primaryColor.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('Split costs with anyone', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Make a group for a trip, a flat or a night out. Add what each person paid and settle up later.',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _newGroup(context),
            icon: const Icon(Icons.add),
            label: const Text('Create a group'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      );

  Widget _ledgerChips(BuildContext context, LedgerView view) {
    final sp = context.read<ExpenseSplitProvider>();
    return SizedBox(
      height: 44,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final l in view.available)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(l.kind == LedgerKind.family ? Icons.home_outlined : Icons.groups_outlined, size: 18),
              label: Text(l.kind == LedgerKind.family ? 'Family' : l.name),
              selected: l == view.ledger,
              onSelected: (_) => sp.load(l),
            ),
          ),
        ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('New group'), onPressed: () => _newGroup(context)),
      ]),
    );
  }

  Widget _content(BuildContext context, LedgerView view, SplitGroupProvider groups, String me) {
    return Consumer<ExpenseSplitProvider>(builder: (context, sp, _) {
      final names = MemberNames(view.members, me);

      if (sp.ledger != view.ledger || (sp.isLoading && sp.splits.isEmpty && sp.settlements.isEmpty)) {
        return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor)));
      }

      final debts = sp.debts;
      final mine = debts.where((d) => d.from == me || d.to == me).toList();
      final others = debts.where((d) => d.from != me && d.to != me).toList();
      final alone = view.members.length < 2;
      final family = context.read<FamilyProvider>();
      final isAdmin = view.isOwner;
      // Referenced so the family provider stays a dependency of this tab (membership changes refresh it).
      family.hasFamily;

      return RefreshIndicator(
        onRefresh: () async {
          await groups.load(silent: true);
          await sp.refresh();
          if (view.isGroup) await groups.loadGroup(view.ledger!.id);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _invitations(context, groups),
            _ledgerChips(context, view),
            const SizedBox(height: 12),
            if (sp.error != null) _banner(sp.error!),
            _balanceCard(sp.myNet),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: alone ? null : () => _newSplit(context),
              icon: const Icon(Icons.add),
              label: const Text('New split'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            if (alone)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: view.isGroup
                    ? TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: view.ledger!.id, myUserId: me)),
                        ),
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Invite someone to start splitting costs'),
                      )
                    : const Text('Invite someone to your family to start splitting costs.',
                        style: TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
              ),
            if (debts.isNotEmpty) ...[
              _sectionTitle('Settle up'),
              for (final d in mine) _debtRow(context, sp, names, d, me),
              if (others.isNotEmpty) ...[
                const SizedBox(height: 4),
                for (final d in others) _debtRow(context, sp, names, d, me),
              ],
            ],
            _sectionTitle('Splits'),
            if (sp.splits.isEmpty)
              const _Empty('No splits yet. Add one when you share a cost.')
            else
              for (final s in sp.splits) _splitTile(context, sp, names, s, me, isAdmin),
            if (sp.settlements.isNotEmpty) ...[
              _sectionTitle('Payments'),
              for (final p in sp.settlements) _paymentTile(context, sp, names, p, me, isAdmin),
            ],
          ],
        ),
      );
    });
  }

  Widget _banner(String msg) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Text(msg, style: const TextStyle(color: Colors.red)),
      );

  Widget _balanceCard(int myNet) {
    final settled = myNet == 0;
    final owed = myNet > 0;
    final color = settled ? AppTheme.textSecondary : (owed ? Colors.green.shade700 : Colors.red.shade700);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Column(children: [
        Text(settled ? 'You\'re all settled up' : (owed ? 'You are owed' : 'You owe'),
            style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(settled ? CurrencyFormatter.format(0) : CurrencyFormatter.format(myNet.abs() / 100),
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );

  Widget _debtRow(BuildContext context, ExpenseSplitProvider sp, MemberNames names, Debt d, String me) {
    final iOwe = d.from == me;
    final owedToMe = d.to == me;
    final text = iOwe
        ? 'You owe ${names.of(d.to)}'
        : owedToMe
            ? '${names.of(d.from)} owes you'
            : '${names.of(d.from)} owes ${names.of(d.to)}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(CurrencyFormatter.format(d.cents / 100),
            style: TextStyle(fontWeight: FontWeight.w800, color: iOwe ? Colors.red.shade700 : (owedToMe ? Colors.green.shade700 : AppTheme.textSecondary))),
        trailing: (iOwe || owedToMe)
            ? FilledButton.tonal(
                onPressed: () => _settleDialog(context, sp, names, d, iOwe),
                child: Text(iOwe ? 'Settle up' : 'Mark paid'),
              )
            : null,
      ),
    );
  }

  Future<void> _settleDialog(BuildContext context, ExpenseSplitProvider sp, MemberNames names, Debt d, bool iOwe) async {
    final cents = await showDialog<int>(
      context: context,
      builder: (_) => _SettleAmountDialog(
        title: iOwe ? 'Pay ${names.of(d.to)}' : 'Payment from ${names.of(d.from)}',
        helper: iOwe
            ? 'Record that you paid them. This only updates your balances; no money moves in the app.'
            : 'Record that they paid you. This only updates your balances.',
        maxCents: d.cents,
      ),
    );
    if (cents == null || !context.mounted) return;
    final ok = await sp.settle(from: d.from, to: d.to, cents: cents);
    if (!context.mounted) return;
    _snack(context, ok ? 'Payment recorded' : (sp.error ?? 'Could not record the payment'));
  }

  Widget _splitTile(BuildContext context, ExpenseSplitProvider sp, MemberNames names, ExpenseSplit s, String me, bool isAdmin) {
    final myShare = s.shares.where((x) => x.userId == me).fold<int>(0, (a, b) => a + b.cents);
    final paidByMe = s.paidBy == me;
    final sub = '${names.of(s.paidBy)} paid · ${s.type.label} · ${DateFormat.MMMd().format(s.createdAt)}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _splitSheet(context, sp, names, s, me, isAdmin),
        title: Text(s.description, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sub),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(CurrencyFormatter.format(s.totalCents / 100), style: const TextStyle(fontWeight: FontWeight.w800)),
          if (paidByMe)
            Text('you lent ${CurrencyFormatter.format((s.totalCents - myShare) / 100)}', style: TextStyle(fontSize: 11, color: Colors.green.shade700))
          else if (myShare > 0)
            Text('your share ${CurrencyFormatter.format(myShare / 100)}', style: TextStyle(fontSize: 11, color: Colors.red.shade700)),
        ]),
      ),
    );
  }

  void _splitSheet(BuildContext context, ExpenseSplitProvider sp, MemberNames names, ExpenseSplit s, String me, bool isAdmin) {
    final canDelete = s.createdBy == me || isAdmin;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.description, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${CurrencyFormatter.format(s.totalCents / 100)} · paid by ${names.of(s.paidBy)} · ${s.type.label}',
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            for (final sh in s.shares)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(names.of(sh.userId))),
                  if (sh.percent != null) Text('${sh.percent!.toStringAsFixed(sh.percent! == sh.percent!.roundToDouble() ? 0 : 2)}%  ', style: const TextStyle(color: AppTheme.textSecondary)),
                  Text(CurrencyFormatter.format(sh.cents / 100), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
            if (canDelete) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final ok = await _confirm(context, 'Delete this split?', 'Balances will be recalculated without it.');
                    if (ok != true || !context.mounted) return;
                    final done = await sp.deleteSplit(s);
                    if (context.mounted) _snack(context, done ? 'Split deleted' : (sp.error ?? 'Could not delete'));
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _paymentTile(BuildContext context, ExpenseSplitProvider sp, MemberNames names, SplitSettlement p, String me, bool isAdmin) {
    final canDelete = p.createdBy == me || isAdmin;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.swap_horiz),
        title: Text('${names.of(p.fromUser)} paid ${names.of(p.toUser)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(DateFormat.MMMd().format(p.createdAt)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(CurrencyFormatter.format(p.cents / 100), style: const TextStyle(fontWeight: FontWeight.w800)),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remove payment',
              onPressed: () async {
                final ok = await _confirm(context, 'Remove this payment?', 'The amount will count as owed again.');
                if (ok != true || !context.mounted) return;
                final done = await sp.deleteSettlement(p);
                if (context.mounted) _snack(context, done ? 'Payment removed' : (sp.error ?? 'Could not remove'));
              },
            ),
        ]),
      ),
    );
  }

  Future<bool?> _confirm(BuildContext context, String title, String body) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
          ],
        ),
      );

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _newSplit(BuildContext context) async {
    final members = watchLedgerViewOnce(context).members;
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => NewSplitScreen(members: members)));
    if (saved == true && context.mounted) _snack(context, 'Split added');
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text(text, style: const TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center)),
      );
}


class _SettleAmountDialog extends StatefulWidget {
  const _SettleAmountDialog({required this.title, required this.helper, required this.maxCents});
  final String title;
  final String helper;
  final int maxCents;

  @override
  State<_SettleAmountDialog> createState() => _SettleAmountDialogState();
}

class _SettleAmountDialogState extends State<_SettleAmountDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: (widget.maxCents / 100).toStringAsFixed(2));
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final c = SplitCalculator.toCents(_ctrl.text);
    if (c == null || c <= 0) {
      setState(() => _error = 'Enter a valid amount');
    } else if (c > widget.maxCents) {
      setState(() => _error = 'That is more than the ${CurrencyFormatter.format(widget.maxCents / 100)} owed');
    } else {
      Navigator.pop(context, c);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.helper, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Amount', prefixText: '\$ ', errorText: _error, border: const OutlineInputBorder()),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Record')),
      ],
    );
  }
}
