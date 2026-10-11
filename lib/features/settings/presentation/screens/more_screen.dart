import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../growth/presentation/providers/growth_provider.dart';
import '../../../growth/presentation/screens/growth_screen.dart';
import '../../../accounts/presentation/screens/accounts_screen.dart';
import '../../../budgets/presentation/screens/budgets_screen.dart';
import '../../../expenses/presentation/screens/expense_list_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../family_accounts/presentation/providers/family_provider.dart';
import '../../../family_accounts/presentation/screens/family_settings_screen.dart';
import '../../../subscription/data/subscription_service.dart';
import '../../../subscription/presentation/screens/paywall_screen.dart';
import '../../../family_accounts/presentation/screens/pending_invitations_screen.dart';
import '../../../influencer_dashboard/presentation/screens/influencer_dashboard_screen.dart';

import '../../../../core/widgets/shell_tabs.dart';
import '../widgets_setting_tiles.dart';

/// The "More" tab: the features that do not have a tab of their own (money screens, family,
/// growth, influencer). App preferences and account actions live in Settings under Profile.
class MoreScreen extends StatelessWidget {
  /// Defaults to the signed-in user's email; tests pass one in.
  const MoreScreen({super.key, this.userEmail});

  final String? userEmail;

  @override
  Widget build(BuildContext context) {
    final email = userEmail ?? _signedInEmail();
    // Budgets has its own tab unless the third tab is Family, so it only needs a row here in that case.
    final tabs = shellTabsFor(
      isMax: context.watch<SubscriptionService>().status.isMax,
      hasFamily: context.watch<FamilyProvider>().hasFamily,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          SettingSection(
            title: 'Money',
            children: [
              SettingTile(
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
              SettingTile(
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
              if (!tabs.contains(ShellTab.budgets))
                SettingTile(
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
              SettingTile(
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
          // Family: a MAX benefit. Members of a family on another plan can still reach it.
          Builder(builder: (context) {
            final isMax = context.watch<SubscriptionService>().status.isMax;
            final inFamily = context.watch<FamilyProvider>().hasFamily;
            final canOpen = isMax || inFamily;
            return SettingSection(
              title: 'Family',
              children: [
                if (canOpen)
                  SettingTile(
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
                  )
                else
                  SettingTile(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Family sharing (MAX)',
                    subtitle: 'Share budgets with up to 10 people',
                    onTap: () => PaywallScreen.show(context, tier: PaywallTier.max),
                  ),
                SettingTile(
                  icon: Icons.mail,
                  title: 'Pending Invitations',
                  subtitle: 'View family invites',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PendingInvitationsScreen(
                          userEmail: email,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          }),
          if (context.watch<GrowthProvider>().isAdmin)
            SettingSection(
              title: 'Growth (admin)',
              children: [
                SettingTile(
                  icon: Icons.campaign_outlined,
                  title: 'Creator outreach',
                  subtitle: 'Task queue and applications',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GrowthScreen()),
                  ),
                ),
              ],
            ),
          SettingSection(
            title: 'Influencer',
            children: [
              SettingTile(
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
        ],
      ),
    );
  }
}

String _signedInEmail() {
  try {
    return Supabase.instance.client.auth.currentUser?.email ?? '';
  } catch (_) {
    return '';
  }
}
