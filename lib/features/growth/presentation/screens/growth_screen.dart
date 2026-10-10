import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/growth_models.dart';
import '../providers/growth_provider.dart';

/// Admin-only: the outreach task queue and creator applications.
/// Agents and the AI only prepare; a person sends every message through the official channel.
class GrowthScreen extends StatefulWidget {
  const GrowthScreen({super.key});
  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<GrowthProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<GrowthProvider>();
    if (p.adminChecked && !p.isAdmin) {
      return Scaffold(
          appBar: AppBar(title: const Text('Growth')),
          body: const Center(child: Text('Admins only')));
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Growth'),
          bottom: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                const Tab(text: 'Queue'),
                Tab(
                    text: p.awaitingReview > 0
                        ? 'Applications (${p.awaitingReview})'
                        : 'Applications'),
              ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAdd(context),
          icon: const Icon(Icons.add),
          label: const Text('Add creator'),
        ),
        body: p.isLoading && p.tasks.isEmpty && p.applications.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_queue(p), _applications(p)]),
      ),
    );
  }

  Widget _queue(GrowthProvider p) {
    final now = DateTime.now();
    final sorted = sortQueue(p.tasks, now);
    if (sorted.isEmpty) {
      return RefreshIndicator(
        onRefresh: p.load,
        child: ListView(children: [
          const SizedBox(height: 120),
          Center(
              child:
                  Text(p.error ?? 'Nothing queued. Add a creator to start.')),
        ]),
      );
    }
    final children = <Widget>[];
    TaskBucket? last;
    const titles = {
      TaskBucket.today: 'Do today',
      TaskBucket.waiting: 'Waiting for a reply',
      TaskBucket.later: 'Later',
      TaskBucket.finished: 'Finished',
    };
    for (final t in sorted) {
      final b = t.bucket(now);
      if (b != last) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child:
              Text(titles[b]!, style: Theme.of(context).textTheme.titleSmall),
        ));
        last = b;
      }
      children.add(_taskTile(t, now));
    }
    children.add(const SizedBox(height: 90));
    return RefreshIndicator(
        onRefresh: p.load, child: ListView(children: children));
  }

  Widget _taskTile(OutreachTask t, DateTime now) {
    final p = context.read<GrowthProvider>();
    final sub = [
      t.channel.label,
      if (t.handle != null) t.handle!,
      if (t.needsFollowUp(now)) 'follow up now',
    ].join(' · ');
    return ListTile(
      title: Text(t.creatorName),
      subtitle: Text(sub),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) =>
            ChangeNotifierProvider.value(value: p, child: _TaskSheet(task: t)),
      ),
    );
  }

  Widget _applications(GrowthProvider p) {
    if (p.applications.isEmpty) {
      return RefreshIndicator(
        onRefresh: p.load,
        child: ListView(children: const [
          SizedBox(height: 120),
          Center(child: Text('No applications yet.'))
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: p.load,
      child: ListView(
        children: [
          for (final a in p.applications)
            ListTile(
              title: Text(a.name),
              subtitle: Text(
                  '${platformLabels[a.platform] ?? a.platform} · ${a.handle} · ${a.status.label}'),
              trailing: a.awaitingDecision
                  ? const Icon(Icons.circle, size: 10, color: Colors.orange)
                  : null,
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => ChangeNotifierProvider.value(
                    value: p, child: _ApplicationSheet(app: a)),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _openAdd(BuildContext context) {
    final p = context.read<GrowthProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          ChangeNotifierProvider.value(value: p, child: const _AddSheet()),
    );
  }
}

class _TaskSheet extends StatefulWidget {
  const _TaskSheet({required this.task});
  final OutreachTask task;
  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late final TextEditingController _notes =
      TextEditingController(text: widget.task.notes ?? '');

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _do(Future<bool> Function() f, String ok,
      {bool close = true}) async {
    final p = context.read<GrowthProvider>();
    final nav = Navigator.of(context);
    final msgr = ScaffoldMessenger.of(context);
    final good = await f();
    msgr.showSnackBar(SnackBar(
        content: Text(good ? ok : (p.error ?? 'Something went wrong'))));
    if (good && close) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final p = context.read<GrowthProvider>();
    final finished = t.bucket(DateTime.now()) == TaskBucket.finished;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.creatorName, style: Theme.of(context).textTheme.titleLarge),
          Text('${t.channel.label}${t.handle != null ? ' · ${t.handle}' : ''}'),
          if (t.niche != null) Text('Niche: ${t.niche}'),
          if (t.fitReason != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Why: ${t.fitReason}')),
          if (t.evidence != null)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Evidence: ${t.evidence}')),
          if (t.draftMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(t.draftMessage!),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (t.draftMessage != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy draft'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: t.draftMessage!));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Draft copied')));
                  }
                },
              ),
            if (t.profileUrl != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open profile'),
                onPressed: () {
                  final u = Uri.tryParse(t.profileUrl!);
                  if (u != null)
                    launchUrl(u, mode: LaunchMode.externalApplication);
                },
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Notes', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          if (!finished)
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (t.status != TaskStatus.sent)
                FilledButton(
                  onPressed: () => _do(
                      () => p.markSent(t), 'Marked sent. Follow-up in 5 days'),
                  child: const Text('Mark sent'),
                ),
              FilledButton.tonal(
                onPressed: () => _do(
                    () => p.setStatus(t, TaskStatus.replied), 'Marked replied'),
                child: const Text('Replied'),
              ),
              OutlinedButton(
                onPressed: () => _do(() => p.setStatus(t, TaskStatus.declined),
                    'Marked declined'),
                child: const Text('Declined'),
              ),
              OutlinedButton(
                onPressed: () => _do(() => p.snooze(t, const Duration(days: 2)),
                    'Snoozed 2 days'),
                child: const Text('Snooze 2d'),
              ),
            ]),
          Row(children: [
            TextButton(
              onPressed: () =>
                  _do(() => p.saveNotes(t, _notes.text), 'Notes saved'),
              child: const Text('Save notes'),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _do(() => p.deleteTask(t), 'Deleted'),
              child: const Text('Delete'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ApplicationSheet extends StatefulWidget {
  const _ApplicationSheet({required this.app});
  final CreatorApplication app;
  @override
  State<_ApplicationSheet> createState() => _ApplicationSheetState();
}

class _ApplicationSheetState extends State<_ApplicationSheet> {
  late final TextEditingController _notes =
      TextEditingController(text: widget.app.adminNotes ?? '');

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _decide(bool approve) async {
    final p = context.read<GrowthProvider>();
    final nav = Navigator.of(context);
    final msgr = ScaffoldMessenger.of(context);
    final ok = approve
        ? await p.approve(widget.app, _notes.text)
        : await p.reject(widget.app, _notes.text);
    msgr.showSnackBar(SnackBar(
        content: Text(ok
            ? (approve
                ? 'Approved. A welcome task is in your queue'
                : 'Rejected')
            : (p.error ?? 'Something went wrong'))));
    if (ok) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.app;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.name, style: Theme.of(context).textTheme.titleLarge),
          Text(a.email),
          const SizedBox(height: 8),
          Text('${platformLabels[a.platform] ?? a.platform} · ${a.handle}'),
          Text(
              'Audience: ${audienceBandLabels[a.audienceBand] ?? a.audienceBand}'),
          Text('Niche: ${a.niche}'),
          if (a.country != null) Text('Country: ${a.country}'),
          if (a.about != null)
            Padding(
                padding: const EdgeInsets.only(top: 8), child: Text(a.about!)),
          const SizedBox(height: 8),
          Text('Status: ${a.status.label}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (a.profileUrl != null)
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open profile'),
              onPressed: () {
                final u = Uri.tryParse(a.profileUrl!);
                if (u != null)
                  launchUrl(u, mode: LaunchMode.externalApplication);
              },
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Notes', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          if (a.awaitingDecision)
            Row(children: [
              Expanded(
                  child: FilledButton(
                      onPressed: () => _decide(true),
                      child: const Text('Approve'))),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => _decide(false),
                      child: const Text('Reject'))),
            ])
          else if (a.status == ApplicationStatus.pendingConfirmation)
            const Text('Waiting for the applicant to confirm their email.'),
        ]),
      ),
    );
  }
}

class _AddSheet extends StatefulWidget {
  const _AddSheet();
  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _url = TextEditingController();
  final _info = TextEditingController();
  final _draft = TextEditingController();
  String _platform = 'tiktok';
  OutreachChannel _channel = OutreachChannel.tiktokInvite;
  String? _niche, _fitReason, _evidence;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _handle, _url, _info, _draft]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _ai() async {
    if (_name.text.trim().isEmpty || _info.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Add a name and paste some info about the creator first')));
      return;
    }
    setState(() => _busy = true);
    final p = context.read<GrowthProvider>();
    final r = await p.draft(
      creatorName: _name.text.trim(),
      platform: _platform,
      channel: _channel,
      handle: _handle.text.trim(),
      profileUrl: _url.text.trim(),
      creatorInfo: _info.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(p.error ?? 'Could not draft')));
      return;
    }
    setState(() {
      _niche = r.niche;
      _fitReason = r.fitReason;
      _evidence = r.evidence;
      _draft.text = r.draft;
    });
    if (r.fits == false) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('AI thinks this is not a fit: ${r.fitReason}')));
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final p = context.read<GrowthProvider>();
    final nav = Navigator.of(context);
    final ok = await p.addTask(
      creatorName: _name.text.trim(),
      platform: _platform,
      channel: _channel,
      handle: _handle.text,
      profileUrl: _url.text,
      niche: _niche,
      fitReason: _fitReason,
      evidence: _evidence,
      draftMessage: _draft.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      nav.pop();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(p.error ?? 'Could not save')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add creator', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _platform,
            decoration: const InputDecoration(labelText: 'Platform'),
            items: [
              for (final e in platformLabels.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value))
            ],
            onChanged: (v) => setState(() {
              _platform = v ?? 'other';
              _channel = OutreachChannel.forPlatform(_platform);
            }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<OutreachChannel>(
            key: ValueKey(_channel),
            initialValue: _channel,
            decoration: const InputDecoration(labelText: 'Send via'),
            items: [
              for (final c in OutreachChannel.values)
                DropdownMenuItem(value: c, child: Text(c.label))
            ],
            onChanged: (v) => setState(() => _channel = v ?? _channel),
          ),
          const SizedBox(height: 16),
          TextField(
              controller: _handle,
              decoration: const InputDecoration(labelText: 'Handle')),
          const SizedBox(height: 16),
          TextField(
              controller: _url,
              decoration: const InputDecoration(labelText: 'Profile link')),
          const SizedBox(height: 16),
          TextField(
            controller: _info,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Paste their bio / recent video titles',
                helperText: 'The AI uses only what you paste'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _ai,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Draft with AI'),
            ),
          ),
          if (_fitReason != null && _fitReason!.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Fit: $_fitReason')),
          const SizedBox(height: 16),
          TextField(
            controller: _draft,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Message draft'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add to queue'),
            ),
          ),
        ]),
      ),
    );
  }
}
