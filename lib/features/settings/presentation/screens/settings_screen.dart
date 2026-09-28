import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../family_accounts/presentation/screens/family_settings_screen.dart';
import '../../../family_accounts/presentation/screens/pending_invitations_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userEmail = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
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
                icon: Icons.info,
                title: 'Version',
                subtitle: '1.0.0',
                onTap: () {},
              ),
            ],
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
