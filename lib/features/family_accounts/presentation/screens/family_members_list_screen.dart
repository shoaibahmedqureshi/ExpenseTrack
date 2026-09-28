import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/family_member.dart';
import '../providers/family_provider.dart';

class FamilyMembersListScreen extends StatefulWidget {
  const FamilyMembersListScreen({super.key});

  @override
  State<FamilyMembersListScreen> createState() =>
      _FamilyMembersListScreenState();
}

class _FamilyMembersListScreenState extends State<FamilyMembersListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FamilyProvider>();
      if (provider.currentFamily != null) {
        provider.loadFamilyMembers(provider.currentFamily!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Members',
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

          if (provider.familyMembers.isEmpty) {
            return const Center(
              child: Text('No members in this family yet'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.familyMembers.length,
            itemBuilder: (context, index) {
              final member = provider.familyMembers[index];
              return _buildMemberCard(context, member, provider);
            },
          );
        },
      ),
    );
  }

  Widget _buildMemberCard(
    BuildContext context,
    FamilyMember member,
    dynamic provider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    member.name?.isNotEmpty == true
                        ? member.name![0].toUpperCase()
                        : member.email[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (member.name?.isNotEmpty == true)
                        Text(
                          member.name!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      Text(
                        member.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildRoleBadge(member.role),
              ],
            ),
            if (provider.isFamilyAdmin && !member.isAdmin)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showRoleChangeDialog(context, member, provider),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Change Role'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showRemoveConfirmation(context, member, provider),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Remove'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(FamilyMemberRole role) {
    final colors = {
      FamilyMemberRole.admin: (AppTheme.primaryColor, Colors.white),
      FamilyMemberRole.member: (AppTheme.primaryColor.withOpacity(0.2), AppTheme.primaryColor),
      FamilyMemberRole.viewer: (AppTheme.surfaceContainer, AppTheme.textSecondary),
    };

    final (bgColor, fgColor) = colors[role]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fgColor,
        ),
      ),
    );
  }

  void _showRoleChangeDialog(
    BuildContext context,
    FamilyMember member,
    dynamic provider,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Role'),
        content: const Text('Select the new role for this member'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await provider.changeMemberRole(member.userId, 'member');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Role changed to Member'
                        : 'Failed to change role'),
                  ),
                );
              }
            },
            child: const Text('Member'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await provider.changeMemberRole(member.userId, 'viewer');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Role changed to Viewer'
                        : 'Failed to change role'),
                  ),
                );
              }
            },
            child: const Text('Viewer'),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmation(
    BuildContext context,
    FamilyMember member,
    dynamic provider,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text(
          'Are you sure you want to remove ${member.name ?? member.email} from the family?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.removeMember(member.userId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Member removed'
                        : 'Failed to remove member'),
                  ),
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
