import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/core/widgets/shell_tabs.dart';

void main() {
  group('shellTabsFor', () {
    test('Free and Pro without a family get Budgets in the third slot', () {
      expect(shellTabsFor(isMax: false, hasFamily: false), [
        ShellTab.dashboard,
        ShellTab.splits,
        ShellTab.budgets,
        ShellTab.more
      ]);
    });

    test('MAX gets Family', () {
      expect(shellTabsFor(isMax: true, hasFamily: false), [
        ShellTab.dashboard,
        ShellTab.splits,
        ShellTab.family,
        ShellTab.more
      ]);
    });

    test('a family member on a lower plan gets Family too', () {
      expect(shellTabsFor(isMax: false, hasFamily: true)[2], ShellTab.family);
    });

    test('there are always four tabs, and never both Budgets and Family', () {
      for (final max in [true, false]) {
        for (final fam in [true, false]) {
          final tabs = shellTabsFor(isMax: max, hasFamily: fam);
          expect(tabs.length, 4);
          expect(
              tabs.contains(ShellTab.budgets) && tabs.contains(ShellTab.family),
              isFalse);
        }
      }
    });

    test('Dashboard and More keep their ends, Splits stays second', () {
      for (final max in [true, false]) {
        final tabs = shellTabsFor(isMax: max, hasFamily: false);
        expect(tabs.first, ShellTab.dashboard);
        expect(tabs[1], ShellTab.splits);
        expect(tabs.last, ShellTab.more);
      }
    });
  });

  group('resolveCurrentTab', () {
    final free = shellTabsFor(isMax: false, hasFamily: false);
    final max = shellTabsFor(isMax: true, hasFamily: false);

    test('a tab that still exists is kept', () {
      expect(resolveCurrentTab(ShellTab.splits, max), ShellTab.splits);
      expect(resolveCurrentTab(ShellTab.budgets, free), ShellTab.budgets);
    });

    test('upgrading while on Budgets moves to Family instead of a missing tab',
        () {
      expect(resolveCurrentTab(ShellTab.budgets, max), ShellTab.family);
    });

    test('losing MAX while on Family moves to Budgets', () {
      expect(resolveCurrentTab(ShellTab.family, free), ShellTab.budgets);
    });

    test('any other missing tab falls back to Dashboard', () {
      expect(
          resolveCurrentTab(
              ShellTab.more, [ShellTab.dashboard, ShellTab.splits]),
          ShellTab.dashboard);
    });
  });
}
