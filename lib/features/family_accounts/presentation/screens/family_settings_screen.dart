import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../subscription/data/subscription_service.dart';
import '../../../subscription/presentation/screens/paywall_screen.dart';
import '../../domain/family_access.dart';
import '../providers/family_provider.dart';
import 'create_family_screen.dart';
import 'invite_members_screen.dart';
import 'family_members_list_screen.dart';

class FamilySettingsScreen extends StatefulWidget {
  const FamilySettingsScreen({super.key});

  @override
  State<FamilySettingsScreen> createState() => _FamilySettingsScreenState();
}

class _FamilySettingsScreenState extends State<FamilySettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FamilyProvider>().loadUserFamilies();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Settings',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Consumer<FamilyProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
              ),
            );
          }

          if (!provider.hasFamily) {
            return _buildNoFamilyState(context);
          }

          final family = provider.currentFamily!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Family Info Card
                _buildFamilyInfoCard(family),
                const SizedBox(height: 24),

                // Quick Stats
                _buildQuickStats(provider),
                const SizedBox(height: 24),

                // Action Buttons
                Text(
                  'Actions',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (provider.isFamilyAdmin &&
                    !canManageFamilyMembers(
                        isMax: context.watch<SubscriptionService>().status.isMax,
                        isAdmin: true)) ...[
                  _buildActionButton(
                    context: context,
                    icon: Icons.workspace_premium_outlined,
                    title: 'Renew MAX to invite more people',
                    subtitle: 'Your family and its members stay as they are',
                    onTap: () => PaywallScreen.show(context),
                  ),
                  const SizedBox(height: 12),
                ],
                if (canManageFamilyMembers(
                    isMax: context.watch<SubscriptionService>().status.isMax,
                    isAdmin: provider.isFamilyAdmin)) ...[
                  _buildActionButton(
                    context: context,
                    icon: Icons.person_add,
                    title: 'Invite Member',
                    subtitle: 'Add someone to your family',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const InviteMembersScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                _buildActionButton(
                  context: context,
                  icon: Icons.group,
                  title: 'Manage Members',
                  subtitle: provider.isFamilyAdmin
                      ? 'View and manage family members'
                      : 'See who is in your family',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FamilyMembersListScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                if (!provider.isFamilyAdmin)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLeave(context, provider),
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Leave Family',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),

                // Danger Zone
                if (provider.isFamilyAdmin)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Danger Zone',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                            ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _showDeleteConfirmation(
                              context, provider, family.id),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text(
                            'Delete Family',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoFamilyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_off,
            size: 64,
            color: AppTheme.primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Family Yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              context.watch<SubscriptionService>().status.canCreateFamily
                  ? 'Create a family to share expenses and budgets with up to 10 members.'
                  : 'Family sharing is part of the MAX plan. Share expenses and budgets with up to 10 people. If someone invited you to their family, you will find the invite under Settings.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          if (context.watch<SubscriptionService>().status.canCreateFamily)
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateFamilyScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Family'),
            )
          else
            FilledButton.icon(
              onPressed: () => PaywallScreen.show(context),
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('Upgrade to MAX to create a family'),
            ),
        ],
      ),
    );
  }

  Widget _buildFamilyInfoCard(dynamic family) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.group,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (family.description != null)
                        Text(
                          family.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(dynamic provider) {
    return Row(
      children: [
        Expanded(
          child: _buildStatBox(
            icon: Icons.people,
            label: 'Members',
            value: '${provider.familyMembers.length}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatBox(
            icon: Icons.admin_panel_settings,
            label: 'Your Role',
            value: provider.isFamilyAdmin ? 'Admin' : 'Member',
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLeave(
      BuildContext context, FamilyProvider provider) async {
    final name = provider.currentFamily?.name ?? 'this family';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave family?'),
        content: Text(
            'You will no longer see $name or its members. You can rejoin only if the admin invites you again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Leave')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await provider.leaveFamily();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'You left $name'
            : (provider.error ?? 'Could not leave the family'))));
  }

  void _showDeleteConfirmation(
      BuildContext context, dynamic provider, String familyId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Family?'),
        content: const Text(
          'This action cannot be undone. All family data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.deleteFamily(familyId);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Family deleted')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete family')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
