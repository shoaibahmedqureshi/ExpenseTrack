import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../../features/expenses/presentation/screens/expense_list_screen.dart';
import '../../features/receipt_scanner/presentation/widgets/scan_fab.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/splits/presentation/screens/splits_screen.dart';
import '../../features/expense_split/presentation/providers/expense_split_provider.dart';
import '../../features/family_accounts/presentation/providers/family_provider.dart';
import '../../features/family_accounts/presentation/screens/family_settings_screen.dart';
import '../../features/household/presentation/providers/household_provider.dart';
import '../../features/household/presentation/screens/household_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

enum _Tab {
  dashboard('Dashboard', Icons.home_outlined, Icons.home),
  splits('Splits', Icons.people_outline, Icons.people),
  family('Family', Icons.group_outlined, Icons.group),
  settings('Settings', Icons.settings_outlined, Icons.settings);

  const _Tab(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Bottom-tab shell for the 4 main screens with the scan button docked in
/// the centre notch. Accounts lives under Settings.
/// Each tab keeps its own Scaffold/AppBar unchanged — this only adds
/// the persistent IndexedStack + nav bar around them.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  _Tab _current = _Tab.dashboard;

  void _select(_Tab tab) {
    setState(() => _current = tab);
    // IndexedStack keeps tabs alive, so refresh the ones that show server data when opened.
    if (tab == _Tab.splits) context.read<ExpenseSplitProvider>().refresh();
    if (tab == _Tab.family) context.read<FamilyProvider>().loadUserFamilies();
  }

  @override
  Widget build(BuildContext context) {
    // The Family tab is always shown so the bar stays balanced. Without MAX it explains the benefit and
    // offers the upgrade; creating a family and inviting people are what need MAX.
    const tabs = _Tab.values;
    final current = _current;

    Widget screenFor(_Tab t) => switch (t) {
          _Tab.dashboard => DashboardScreen(
              onOpenSplits: () => _select(_Tab.splits),
              onOpenFamily: () => _select(_Tab.family),
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
          _Tab.splits => const SplitsScreen(),
          _Tab.family => const FamilySettingsScreen(),
          _Tab.settings => const SettingsScreen(),
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
// Dashboard, Splits | scan | Family, Settings.
class _NavBar extends StatelessWidget {
  const _NavBar(
      {required this.tabs, required this.current, required this.onTap});

  final List<_Tab> tabs;
  final _Tab current;
  final void Function(_Tab) onTap;

  Widget _item(_Tab tab) {
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
