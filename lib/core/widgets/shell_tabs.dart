import 'package:flutter/material.dart';

/// The destinations the bottom bar can show. The third slot depends on the plan: MAX users and
/// family members get Family, everyone else gets Budgets.
enum ShellTab {
  dashboard('Dashboard', Icons.home_outlined, Icons.home),
  splits('Splits', Icons.people_outline, Icons.people),
  budgets('Budgets', Icons.pie_chart_outline, Icons.pie_chart),
  family('Family', Icons.group_outlined, Icons.group),
  more('More', Icons.menu, Icons.menu_open);

  const ShellTab(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Four tabs around the scan button. Family is only worth a tab to someone who can use it.
List<ShellTab> shellTabsFor({required bool isMax, required bool hasFamily}) => [
      ShellTab.dashboard,
      ShellTab.splits,
      isMax || hasFamily ? ShellTab.family : ShellTab.budgets,
      ShellTab.more,
    ];

/// Keeps the user on a sensible tab when the plan changes under them: someone looking at Budgets
/// who upgrades (or joins a family) lands on the new third tab instead of a tab that disappeared.
ShellTab resolveCurrentTab(ShellTab current, List<ShellTab> tabs) {
  if (tabs.contains(current)) return current;
  if (current == ShellTab.budgets || current == ShellTab.family) return tabs[2];
  return ShellTab.dashboard;
}
