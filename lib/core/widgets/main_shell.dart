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
import '../../features/settings/presentation/screens/settings_screen.dart';

const _tabLabels = ['Dashboard', 'Splits', 'Family', 'Settings'];
const _tabIcons = [
  Icons.home_outlined,
  Icons.people_outline,
  Icons.group_outlined,
  Icons.settings_outlined,
];
const _tabActiveIcons = [
  Icons.home,
  Icons.people,
  Icons.group,
  Icons.settings,
];

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
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Each screen's state is preserved across tab switches via IndexedStack
    final screens = [
      DashboardScreen(
        onOpenSplits: () {
          setState(() => _index = 1);
          context.read<ExpenseSplitProvider>().refresh();
        },
        onOpenFamily: () {
          setState(() => _index = 2);
          context.read<FamilyProvider>().loadUserFamilies();
        },
        onSeeAllTransactions: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExpenseListScreen()),
        ),
      ),
      const SplitsScreen(),
      const FamilySettingsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      // The FAB and the bar must belong to the same Scaffold for the notch to
      // cut around the docked button.
      floatingActionButton: const ScanFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _NavBar(
        index: _index,
        onTap: (i) {
          setState(() => _index = i);
          // IndexedStack keeps the Family tab alive, so refresh it on open.
          if (i == 1) context.read<ExpenseSplitProvider>().refresh();
          if (i == 2) context.read<FamilyProvider>().loadUserFamilies();
        },
      ),
    );
  }
}

// BottomAppBar with 4 equal-width tabs and a notch for the centred scan FAB:
// Dashboard, Splits | scan | Family, Settings.
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
            _item(0),
            _item(1),
            _item(2),
            _item(3),
          ],
        ),
      ),
    );
  }
}
