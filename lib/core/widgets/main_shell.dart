import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../features/accounts/presentation/screens/accounts_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/splits/presentation/screens/splits_screen.dart';
import '../../features/family/presentation/screens/family_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

const _tabLabels = ['Dashboard', 'Accounts', 'Splits', 'Family', 'Settings'];
const _tabIcons = [
  Icons.home_outlined,
  Icons.account_balance_wallet_outlined,
  Icons.people_outline,
  Icons.group_outlined,
  Icons.settings_outlined,
];
const _tabActiveIcons = [
  Icons.home,
  Icons.account_balance_wallet,
  Icons.people,
  Icons.group,
  Icons.settings,
];

/// Bottom-tab shell for the 5 main screens (Phase 1a).
/// Each tab keeps its own Scaffold/AppBar unchanged — this only adds
/// the persistent IndexedStack + nav bar around them.
/// Phase 1a: Dashboard, Accounts, Splits, Family, Settings
/// FAB moved to Dashboard screen for Phase 1b restructuring.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // 5-tab navigation: Dashboard, Accounts, Splits, Family, Settings
    // Each screen's state is preserved across tab switches via IndexedStack
    final screens = [
      DashboardScreen(onSeeAllTransactions: () => setState(() => _index = 1)),
      const AccountsScreen(),
      const SplitsScreen(),
      const FamilyScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      // FAB moved to Dashboard screen for Phase 1a
      // Will be repositioned in Phase 1b after scan feature is finalized
      bottomNavigationBar: _NavBar(
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

// BottomAppBar with 5 equal-width tabs for Phase 1a:
// Dashboard, Accounts, Splits, Family, Settings
// All tabs get equal-width Expanded slots using flexible layout.
// Tab pill width adjusted for 5-tab layout (65px vs 78px for 4 tabs).
class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});

  final int index;
  final void Function(int) onTap;

  Widget _item(int i) {
    final active = i == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(i),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            // Fixed width for 5 tabs: adjusted from 78px (4-tab layout)
            // to fit all tabs proportionally. With 5 tabs, smaller width
            // ensures each tab has equal visual space without overlap.
            width: 65,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
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
                  active ? _tabActiveIcons[i] : _tabIcons[i],
                  size: 20,
                  color: active ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
                const SizedBox(height: 2),
                Text(
                  _tabLabels[i],
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.0,
                    fontWeight: FontWeight.w600,
                    color: active ? AppTheme.primaryColor : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
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
            _item(0),
            _item(1),
            _item(2),
            _item(3),
            _item(4),
          ],
        ),
      ),
    );
  }
}
