import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/family_provider.dart';

class InviteMembersScreen extends StatefulWidget {
  const InviteMembersScreen({super.key});

  @override
  State<InviteMembersScreen> createState() => _InviteMembersScreenState();
}

class _InviteMembersScreenState extends State<InviteMembersScreen> {
  late TextEditingController _emailController;
  String _selectedRole = 'member';
  bool _isInviting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvitation() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Please enter an email address');
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      _showMessage('Please enter a valid email address');
      return;
    }

    final provider = context.read<FamilyProvider>();
    if (provider.currentFamily == null) {
      _showMessage('No family selected');
      return;
    }

    setState(() => _isInviting = true);

    final success = await provider.inviteMember(
      familyGroupId: provider.currentFamily!.id,
      email: email,
      role: _selectedRole,
    );

    if (mounted) {
      if (success) {
        _showMessage('Invitation sent to $email!');
        _emailController.clear();
        _selectedRole = 'member';
      } else {
        _showMessage(provider.error ?? 'Failed to send invitation');
      }
      setState(() => _isInviting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Members',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Consumer<FamilyProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info, color: AppTheme.primaryColor, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Invitations expire after 7 days. The invited person will receive an email notification.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Email Input
                Text(
                  'Email Address',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  enabled: !_isInviting,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'example@email.com',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Role Selection
                Text(
                  'Role',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedRole,
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(
                        value: 'member',
                        child: Row(
                          children: const [
                            Icon(Icons.person, size: 18),
                            SizedBox(width: 12),
                            Text('Member (Can log expenses)'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'viewer',
                        child: Row(
                          children: const [
                            Icon(Icons.visibility, size: 18),
                            SizedBox(width: 12),
                            Text('Viewer (Read-only)'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: _isInviting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedRole = value);
                            }
                          },
                  ),
                ),
                const SizedBox(height: 24),

                // Role Descriptions
                _buildRoleDescription(
                  title: 'Member',
                  description: 'Can view family expenses, budgets, and add new transactions.',
                ),
                const SizedBox(height: 12),
                _buildRoleDescription(
                  title: 'Viewer',
                  description: 'Can view family expenses and reports, but cannot make changes.',
                ),
                const SizedBox(height: 32),

                // Send Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isInviting ? null : _sendInvitation,
                    child: _isInviting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('Send Invitation'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoleDescription({
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
