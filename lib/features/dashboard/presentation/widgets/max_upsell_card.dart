import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../family_accounts/presentation/providers/family_provider.dart';
import '../../../subscription/data/subscription_service.dart';

const _kDismissedAt = 'max_card_dismissed_at';
const maxCardSnooze = Duration(days: 30);

/// Whether to offer MAX on the Dashboard: only to someone who has neither MAX nor a family, and not for
/// [maxCardSnooze] after they dismissed it.
bool shouldShowMaxCard({
  required bool isMax,
  required bool hasFamily,
  required DateTime? dismissedAt,
  required DateTime now,
}) {
  if (isMax || hasFamily) return false;
  if (dismissedAt == null) return true;
  return now.difference(dismissedAt) >= maxCardSnooze;
}

/// The Family tab is only shown to people who can use it, so this is where everyone else hears about MAX.
class MaxUpsellCard extends StatefulWidget {
  const MaxUpsellCard({super.key, required this.onUpgrade, this.now});

  final VoidCallback onUpgrade;

  /// Overridable clock for tests.
  final DateTime Function()? now;

  @override
  State<MaxUpsellCard> createState() => _MaxUpsellCardState();
}

class _MaxUpsellCardState extends State<MaxUpsellCard> {
  DateTime? _dismissedAt;
  bool _loaded = false;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    DateTime? at;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_kDismissedAt);
      if (ms != null) at = DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      // Without storage the card simply shows; dismissing lasts until the app restarts.
    }
    if (mounted)
      setState(() {
        _dismissedAt = at;
        _loaded = true;
      });
  }

  Future<void> _dismiss() async {
    final now = _now();
    setState(() => _dismissedAt = now);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kDismissedAt, now.millisecondsSinceEpoch);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isMax = context.watch<SubscriptionService>().status.isMax;
    final hasFamily = context.watch<FamilyProvider>().likelyHasFamily;
    if (!_loaded ||
        !shouldShowMaxCard(
            isMax: isMax,
            hasFamily: hasFamily,
            dismissedAt: _dismissedAt,
            now: _now())) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onUpgrade,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
            child: Row(children: [
              const Icon(Icons.group_outlined, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Budget together with MAX',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Share a family budget with up to 10 people.',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                    ]),
              ),
              IconButton(
                tooltip: 'Not now',
                icon: const Icon(Icons.close,
                    size: 18, color: AppTheme.textSecondary),
                onPressed: _dismiss,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
