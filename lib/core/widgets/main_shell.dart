import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../features/budgets/presentation/screens/budgets_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/expenses/presentation/screens/expense_list_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/receipt_scanner/presentation/widgets/scan_fab.dart';

const _tabLabels = ['Dashboard', 'Transactions', 'Budgets', 'Reports'];
const _tabIcons = [
  Icons.home_outlined,
  Icons.receipt_long_outlined,
  Icons.pie_chart_outline,
  Icons.bar_chart_outlined,
];
const _tabActiveIcons = [
  Icons.home,
  Icons.receipt_long,
  Icons.pie_chart,
  Icons.bar_chart,
];

/// Bottom-tab shell for the 4 main screens. Each tab keeps its own
/// Scaffold/AppBar unchanged — this only adds the persistent IndexedStack
/// + nav bar around them. The scan FAB moved here (out of Dashboard's and
/// Transactions' own Scaffolds) because docking it into a notch cut into
/// the nav bar requires the FAB and the bar to be owned by the same
/// Scaffold — Flutter can't dock a FAB into a bar declared by a different,
/// nested Scaffold.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Not a static const list: Dashboard's "Show more" button needs a way
    // to switch to the Transactions tab, so it takes a callback rather
    // than being a fixed widget. IndexedStack still preserves each
    // screen's State across rebuilds since they stay at the same list
    // position with the same widget type.
    final screens = [
      DashboardScreen(onSeeAllTransactions: () => setState(() => _index = 1)),
      const ExpenseListScreen(),
      const BudgetsScreen(),
      const ReportsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      floatingActionButton: const ScanFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _NavBar(
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

// BottomAppBar rather than a plain container: its shape/notchMargin cut an
// actual notch around the docked FAB so it sits embedded in the middle of
// the bar (matching the approved mockup) instead of floating above it. All
// 4 tabs get equal-width Expanded slots with no manual gap between them —
// the notch is painted based on the FAB's actual centered position
// regardless of the row's own layout, so reserving a gap in the middle
// isn't necessary and previously made tabs 1/2 look offset from 0/3.
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
            // Fixed width rather than symmetric padding around the text:
            // padding-based sizing meant each pill was only as wide as its
            // own label ("Transactions" vs "Budgets"), so the pills
            // themselves were different widths even though the cells
            // holding them were equal — that unevenness is what read as
            // "spacing between tabs is not equal". A shared fixed width
            // makes every pill identical regardless of label length.
            width: 78,
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
          ],
        ),
      ),
    );
  }
}
