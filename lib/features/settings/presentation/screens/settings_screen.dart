import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../accounts/presentation/screens/accounts_screen.dart';
import '../../../budgets/presentation/screens/budgets_screen.dart';
import '../../../expenses/presentation/screens/expense_list_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../family_accounts/presentation/screens/family_settings_screen.dart';
import '../../../family_accounts/presentation/screens/pending_invitations_screen.dart';
import '../../../influencer_dashboard/presentation/screens/influencer_dashboard_screen.dart';
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
      path: 'contact@outlayapp.net',
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
    final userEmail = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          _SettingSection(
            title: 'Money',
            children: [
              _SettingTile(
                icon: Icons.account_balance_wallet,
                title: 'Accounts',
                subtitle: 'Your accounts and SMS auto-logging',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountsScreen()),
                  );
                },
              ),
              _SettingTile(
                icon: Icons.receipt_long,
                title: 'Transactions',
                subtitle: 'All income and expenses',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ExpenseListScreen()),
                  );
                },
              ),
              _SettingTile(
                icon: Icons.pie_chart,
                title: 'Budgets',
                subtitle: 'Monthly and category budgets',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BudgetsScreen()),
                  );
                },
              ),
              _SettingTile(
                icon: Icons.bar_chart,
                title: 'Reports',
                subtitle: 'Spending by category and trends',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportsScreen()),
                  );
                },
              ),
            ],
          ),
          // Family Section (MAX Tier)
          _SettingSection(
            title: 'Family (MAX)',
            children: [
              _SettingTile(
                icon: Icons.group,
                title: 'Family Settings',
                subtitle: 'Manage family & members',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FamilySettingsScreen(),
                    ),
                  );
                },
              ),
              _SettingTile(
                icon: Icons.mail,
                title: 'Pending Invitations',
                subtitle: 'View family invites',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PendingInvitationsScreen(
                        userEmail: userEmail,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          _SettingSection(
            title: 'Influencer',
            children: [
              _SettingTile(
                icon: Icons.trending_up,
                title: 'Revenue Dashboard',
                subtitle: 'Track influencer codes',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InfluencerDashboardScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          _SettingSection(
            title: 'App',
            children: [
              _SettingTile(
                icon: Icons.language,
                title: 'Language',
                subtitle: 'English',
                onTap: () {},
              ),
              _SettingTile(
                icon: Icons.dark_mode,
                title: 'Theme',
                subtitle: 'System',
                onTap: () {},
              ),
            ],
          ),
          _SettingSection(
            title: 'About',
            children: [
              _SettingTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How we handle your data',
                onTap: _openPrivacyPolicy,
              ),
              _SettingTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'Terms of use',
                onTap: _openTermsOfService,
              ),
              _SettingTile(
                icon: Icons.info,
                title: 'Version',
                subtitle: '1.0.0',
                onTap: () {},
              ),
            ],
          ),
          const _SettingSection(title: 'Account', children: []),
          ListTile(
            leading:
                const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text('Delete Account',
                style: TextStyle(color: Colors.red)),
            onTap: _requestAccountDeletion,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: OutlinedButton.icon(
              onPressed: auth.loading ? null : _signOut,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Sign Out',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
