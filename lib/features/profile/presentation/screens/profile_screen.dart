import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../subscription/data/subscription_service.dart';
import '../../../subscription/presentation/screens/paywall_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  String _currency = 'USD';
  bool _editing = false;

  static const _currencies = ['USD', 'EUR', 'GBP', 'PKR', 'AED', 'SAR', 'CAD', 'AUD'];

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    _nameCtrl.text = profile?.name ?? '';
    _currency = profile?.currency ?? 'USD';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context.read<AuthProvider>().updateProfile(
          name: _nameCtrl.text.trim(),
          currency: _currency,
        );
    if (mounted) setState(() => _editing = false);
  }

  static const _privacyPolicyUrl =
      'https://shoaibahmedqureshi.github.io/ExpenseTrack/privacy.html';

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(_privacyPolicyUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _requestAccountDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all your data '
          '(expenses, budgets, categories). This cannot be undone. '
          'We\'ll email you to confirm before deleting.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Request Deletion')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final email = context.read<AuthProvider>().profile?.email ?? '';
    final uri = Uri(
      scheme: 'mailto',
      path: '08bitsaqureshi@seecs.edu.pk',
      query:
          'subject=Outlay account deletion request&body=Please delete my Outlay account and all associated data.%0A%0AAccount email: $email',
    );
    await launchUrl(uri);
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
            )
          else
            TextButton(
              onPressed: auth.loading ? null : _save,
              child: const Text('Save',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppTheme.primaryColor.withOpacity(.15),
                  child: Text(
                    (profile?.name?.isNotEmpty == true
                            ? profile!.name![0]
                            : profile?.email[0] ?? '?')
                        .toUpperCase(),
                    style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor),
                  ),
                ),
                if (_editing)
                  const Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.primaryColor,
                      child: Icon(Icons.camera_alt,
                          size: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              profile?.email ?? '',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ),
          const SizedBox(height: 32),

          // Info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _editing
                      ? TextFormField(
                          controller: _nameCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Full Name'),
                          textCapitalization: TextCapitalization.words,
                        )
                      : _InfoRow(
                          icon: Icons.person_outline,
                          label: 'Name',
                          value: profile?.name ?? 'Not set'),
                  const Divider(height: 24),
                  _editing
                      ? DropdownButtonFormField<String>(
                          value: _currency,
                          decoration:
                              const InputDecoration(labelText: 'Currency'),
                          items: _currencies
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _currency = v ?? 'USD'),
                        )
                      : _InfoRow(
                          icon: Icons.attach_money,
                          label: 'Currency',
                          value: profile?.currency ?? 'USD'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Subscription card
          Consumer<SubscriptionService>(
            builder: (context, svc, _) {
              final isPro = svc.status.isPro;
              final scansLeft = svc.status.scansRemaining;
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        isPro ? Icons.workspace_premium : Icons.lock_open_outlined,
                        color: isPro ? const Color(0xFFFFD700) : AppTheme.primaryColor,
                      ),
                      title: Text(isPro ? 'Pro Plan' : 'Free Plan'),
                      subtitle: Text(isPro
                          ? 'Unlimited scans & reports'
                          : '$scansLeft receipt scans remaining this month'),
                      trailing: isPro
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('PRO',
                                  style: TextStyle(
                                      color: Color(0xFFB8860B),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                            )
                          : TextButton(
                              onPressed: () => PaywallScreen.show(context),
                              child: const Text('Upgrade'),
                            ),
                    ),
                    if (!isPro) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (30 - scansLeft) / 30,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              scansLeft <= 5 ? Colors.red : AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Sync status card
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_done_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('Cloud Sync'),
              subtitle: const Text('Data is backed up to Supabase'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Active',
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legal / account actions
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: AppTheme.primaryColor),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: _openPrivacyPolicy,
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.delete_forever_outlined, color: Colors.red),
                  title: const Text('Delete Account',
                      style: TextStyle(color: Colors.red)),
                  onTap: _requestAccountDeletion,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sign out
          OutlinedButton.icon(
            onPressed: auth.loading ? null : _signOut,
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Sign Out',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
