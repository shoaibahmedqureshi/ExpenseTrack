import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import 'shell_tabs.dart';
import '../../features/expenses/presentation/screens/expense_list_screen.dart';
import '../../features/receipt_scanner/presentation/widgets/scan_fab.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/splits/presentation/screens/splits_screen.dart';
import '../../features/expense_split/presentation/providers/expense_split_provider.dart';
import '../../features/family_accounts/presentation/providers/family_provider.dart';
import '../../features/family_accounts/presentation/screens/family_settings_screen.dart';
import '../../features/household/presentation/providers/household_provider.dart';
import '../../features/household/presentation/screens/household_screen.dart';
import '../../features/budgets/presentation/screens/budgets_screen.dart';
import '../../features/settings/presentation/screens/more_screen.dart';
import '../../features/subscription/data/subscription_service.dart';

/// Bottom-tab shell for the 4 main screens with the scan button docked in
/// the centre notch. Accounts lives under More.
/// Each tab keeps its own Scaffold/AppBar unchanged — this only adds
/// the persistent IndexedStack + nav bar around them.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  ShellTab _current = ShellTab.dashboard;

  void _select(ShellTab tab) {
    setState(() => _current = tab);
    // IndexedStack keeps tabs alive, so refresh the ones that show server data when opened.
    if (tab == ShellTab.splits) context.read<ExpenseSplitProvider>().refresh();
    if (tab == ShellTab.family) context.read<FamilyProvider>().loadUserFamilies();
  }

  @override
  Widget build(BuildContext context) {
    // The third tab is Family for MAX users and family members, Budgets for everyone else. The plan can
    // change while the app is open (a purchase, an accepted invite), so the list is rebuilt each time.
    final isMax = context.watch<SubscriptionService>().status.isMax;
    final hasFamily = context.watch<FamilyProvider>().likelyHasFamily;
    final tabs = shellTabsFor(isMax: isMax, hasFamily: hasFamily);
    final current = resolveCurrentTab(_current, tabs);

    Widget screenFor(ShellTab t) => switch (t) {
          ShellTab.dashboard => DashboardScreen(
              onOpenSplits: () => _select(ShellTab.splits),
              onOpenFamily: () => _select(ShellTab.family),
              onOpenHousehold: () {
                final id = context.read<HouseholdProvider>().familyId;
                if (id == null) return;
                Navigator.push(context, MaterialPageRoute(builder: (_) => HouseholdScreen(familyId: id)));
              },
              onSeeAllTransactions: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpenseListScreen()),
              ),
            ),
          ShellTab.splits => const SplitsScreen(),
          ShellTab.budgets => const BudgetsScreen(),
          ShellTab.family => const FamilySettingsScreen(),
          ShellTab.more => const MoreScreen(),
        };

    // Each screen's state is preserved across tab switches via IndexedStack; keys keep a tab's state
    // when another tab appears or disappears around it.
    return Scaffold(
      body: IndexedStack(
        index: tabs.indexOf(current),
        children: [
          for (final t in tabs)
            KeyedSubtree(key: ValueKey(t), child: screenFor(t))
        ],
      ),
      // The FAB and the bar must belong to the same Scaffold for the notch to
      // cut around the docked button.
      floatingActionButton: const ScanFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar:
          _NavBar(tabs: tabs, current: current, onTap: _select),
    );
  }
}

// BottomAppBar with equal-width tabs and a notch for the centred scan FAB:
// Dashboard, Splits | scan | Budgets or Family, More.
class _NavBar extends StatelessWidget {
  const _NavBar(
      {required this.tabs, required this.current, required this.onTap});

  final List<ShellTab> tabs;
  final ShellTab current;
  final void Function(ShellTab) onTap;

  Widget _item(ShellTab tab) {
    final active = tab == current;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(tab),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.primaryColor.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active ? tab.activeIcon : tab.icon,
                    size: 20,
                    color:
                        active ? AppTheme.primaryColor : AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tab.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.0,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondary,
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: AppTheme.cardColor,
      height: 66 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: 66,
        child: Row(
          children: [
            _item(tabs[0]),
            _item(tabs[1]),
            for (final t in tabs.skip(2)) _item(t),
          ],
        ),
      ),
    );
  }
}
