import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/inbox_item.dart';
import '../providers/inbox_provider.dart';

/// Pops with a target key ('splits', 'family', 'invites') when a notification is tapped.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<InboxProvider>().load(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<InboxProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (inbox.unreadCount > 0)
            TextButton(
              onPressed: inbox.markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: inbox.items.isEmpty
          ? (inbox.isLoading
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor)))
              : _empty(context))
          : RefreshIndicator(
              onRefresh: () => inbox.load(silent: true),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: inbox.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) => _tile(context, inbox, inbox.items[i]),
              ),
            ),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_none, size: 64, color: AppTheme.primaryColor.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('You\'re all caught up', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text('New splits, payments and family invitations will show up here.',
                textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ]),
      );

  Widget _tile(BuildContext context, InboxProvider inbox, InboxItem item) {
    return Dismissible(
      key: ValueKey('inbox-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => inbox.delete(item),
      child: ListTile(
        tileColor: item.isRead ? null : AppTheme.primaryColor.withOpacity(0.06),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
          child: Icon(_icon(item.type), color: AppTheme.primaryColor, size: 20),
        ),
        title: Text(item.title, style: TextStyle(fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.body),
            const SizedBox(height: 4),
            Text(_ago(item.createdAt), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ]),
        ),
        trailing: item.isRead
            ? null
            : const Icon(Icons.circle, size: 10, color: AppTheme.primaryColor),
        onTap: () async {
          await inbox.markRead(item);
          if (context.mounted) Navigator.pop(context, item.target);
        },
      ),
    );
  }

  IconData _icon(String type) => switch (type) {
        'split_added' => Icons.call_split,
        'payment_recorded' => Icons.payments_outlined,
        'family_invite' => Icons.mail_outline,
        'member_joined' || 'group_member_joined' => Icons.person_add_alt,
        'group_invite' => Icons.group_add_outlined,
        'creator_application' => Icons.campaign_outlined,
        _ => Icons.notifications_none,
      };

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat.MMMd().format(t);
  }
}
