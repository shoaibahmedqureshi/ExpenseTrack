import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../expense_split/presentation/providers/expense_split_provider.dart';
import '../../domain/group_models.dart';
import '../providers/split_group_provider.dart';

/// Members, invitations and housekeeping for one split group.
class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId, required this.myUserId});
  final int groupId;
  final String myUserId;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<SplitGroupProvider>().loadGroup(widget.groupId));
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(Future<bool> Function() action, String ok) async {
    setState(() => _busy = true);
    final p = context.read<SplitGroupProvider>();
    final done = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(done ? ok : (p.error ?? 'Something went wrong'));
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      (await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: Text(action)),
          ],
        ),
      )) ==
      true;

  Future<void> _rename(SplitGroup g) async {
    final name = await showDialog<String>(context: context, builder: (_) => _NameDialog(title: 'Rename group', initial: g.name));
    if (name == null || !mounted) return;
    await _run(() => context.read<SplitGroupProvider>().rename(g.id, name), 'Group renamed');
  }

  Future<void> _invite() async {
    final text = _email.text.trim();
    if (text.isEmpty) return;
    final p = context.read<SplitGroupProvider>();
    setState(() => _busy = true);
    final ok = await p.invite(widget.groupId, text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _email.clear();
    _snack(ok ? (p.inviteNote ?? 'Invitation sent') : (p.error ?? 'Could not send the invitation'));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SplitGroupProvider>();
    final g = p.byId(widget.groupId);
    if (g == null) {
      return Scaffold(appBar: AppBar(title: const Text('Group')), body: const Center(child: Text('This group is no longer available')));
    }
    final members = p.membersOf(g.id);
    final sent = p.sentInvitationsOf(g.id);
    final full = members.length + sent.length >= maxGroupMembers;

    return Scaffold(
      appBar: AppBar(
        title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [if (g.isOwner) IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Rename', onPressed: () => _rename(g))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Invite someone', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enabled: !full,
              decoration: InputDecoration(
                hintText: full ? 'This group is full ($maxGroupMembers people)' : 'Their email address',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _invite(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: (_busy || full) ? null : _invite, child: const Text('Invite')),
        ]),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('If they do not have Outlay yet, we email them how to join. The invitation stays open for 14 days.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ),
        const SizedBox(height: 20),
        Text('Members (${members.length}/$maxGroupMembers)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        for (final m in members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(((m.name ?? m.email).isEmpty ? '?' : (m.name ?? m.email)[0]).toUpperCase())),
            title: Text(m.userId == widget.myUserId ? '${m.name ?? m.email.split('@').first} (you)' : (m.name ?? m.email.split('@').first)),
            subtitle: Text(m.isOwner ? 'Owner · ${m.email}' : m.email),
            trailing: (g.isOwner && m.userId != widget.myUserId)
                ? IconButton(
                    icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                    tooltip: 'Remove',
                    onPressed: _busy
                        ? null
                        : () async {
                            if (!await _confirm('Remove ${m.name ?? m.email}?', 'They must have no unsettled balance in this group.', 'Remove')) return;
                            if (!mounted) return;
                            await _run(() => context.read<SplitGroupProvider>().removeMember(g.id, m.userId), 'Removed');
                          },
                  )
                : null,
          ),
        if (sent.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Waiting to join', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          for (final i in sent)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.mail_outline, size: 18)),
              title: Text(i.email),
              trailing: TextButton(
                onPressed: _busy ? null : () => _run(() => context.read<SplitGroupProvider>().cancelInvitation(g.id, i), 'Invitation cancelled'),
                child: const Text('Cancel'),
              ),
            ),
        ],
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  if (!await _confirm('Leave ${g.name}?', 'You can only leave when you have no unsettled balance.', 'Leave')) return;
                  if (!mounted) return;
                  final p2 = context.read<SplitGroupProvider>();
                  final splits = context.read<ExpenseSplitProvider>();
                  final nav = Navigator.of(context);
                  final ok = await p2.leave(g.id);
                  if (!mounted) return;
                  if (ok) {
                    splits.loadOverview();
                    nav.pop();
                  } else {
                    _snack(p2.error ?? 'Could not leave the group');
                  }
                },
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Leave group', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), minimumSize: const Size.fromHeight(46)),
        ),
        if (g.isOwner) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    if (!await _confirm('Delete ${g.name}?', 'Its splits and payments are deleted for everyone. Everyone must be settled up first.', 'Delete')) return;
                    if (!mounted) return;
                    final p2 = context.read<SplitGroupProvider>();
                    final splits = context.read<ExpenseSplitProvider>();
                    final nav = Navigator.of(context);
                    final ok = await p2.delete(g.id);
                    if (!mounted) return;
                    if (ok) {
                      splits.loadOverview();
                      nav.pop();
                    } else {
                      _snack(p2.error ?? 'Could not delete the group');
                    }
                  },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Delete group', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), minimumSize: const Size.fromHeight(46)),
          ),
        ],
      ]),
    );
  }
}

/// Used to name or rename a group. A StatefulWidget so the controller lives and dies with the dialog.
class NameDialog extends StatelessWidget {
  const NameDialog({super.key});
  @override
  Widget build(BuildContext context) => const _NameDialog(title: 'New group');
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, this.initial = ''});
  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _c,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Group name', hintText: 'Goa trip, Flat 4B…', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final t = _c.text.trim();
              if (t.isNotEmpty) Navigator.pop(context, t);
            },
            child: const Text('Save'),
          ),
        ],
      );
}
