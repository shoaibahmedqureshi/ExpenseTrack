import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _openPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  void _openTermsOfService() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
    );
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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: AppTheme.primaryColor),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _openPrivacyPolicy,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined,
                      color: AppTheme.primaryColor),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _openTermsOfService,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.delete_forever_outlined, color: Colors.red),
              title: const Text('Delete Account',
                  style: TextStyle(color: Colors.red)),
              onTap: _requestAccountDeletion,
            ),
          ),
          const SizedBox(height: 16),

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
