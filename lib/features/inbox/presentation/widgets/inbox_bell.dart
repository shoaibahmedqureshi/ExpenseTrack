import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inbox_provider.dart';
import '../screens/inbox_screen.dart';

/// App-bar bell with an unread badge. [onTarget] receives 'splits', 'family' or 'invites'.
class InboxBell extends StatelessWidget {
  const InboxBell({super.key, required this.onTarget});

  final void Function(String target) onTarget;

  @override
  Widget build(BuildContext context) {
    final unread = context.select<InboxProvider, int>((p) => p.unreadCount);
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () async {
        final target = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const InboxScreen()),
        );
        if (target != null && target.isNotEmpty) onTarget(target);
      },
      icon: Stack(clipBehavior: Clip.none, children: [
        const Icon(Icons.notifications_none, size: 26, color: Colors.white),
        if (unread > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
              child: Text(unread > 9 ? '9+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }
}
