import '../../expenses/domain/entities/expense.dart';
import 'household_models.dart';

/// How spending compares with a budget. All money is whole cents.
class BudgetStatus {
  const BudgetStatus({required this.budgetCents, required this.spentCents});
  final int budgetCents;
  final int spentCents;

  int get remainingCents => budgetCents - spentCents;
  bool get isOver => spentCents > budgetCents;

  /// 0 to 1 for a progress bar (more than the budget still shows a full bar).
  double get fraction => budgetCents <= 0 ? 0 : (spentCents / budgetCents).clamp(0.0, 1.0);

  /// Whole-number percent of the budget used, which can go past 100.
  int get percentUsed => budgetCents <= 0 ? 0 : (spentCents * 100 / budgetCents).round();
}

class CategoryLine {
  const CategoryLine({required this.category, required this.spentCents, this.budgetCents});
  final String category;
  final int spentCents;
  final int? budgetCents;

  BudgetStatus? get status => budgetCents == null ? null : BudgetStatus(budgetCents: budgetCents!, spentCents: spentCents);
}

class HouseholdCalculator {
  HouseholdCalculator._();

  /// Everything the people who are sharing have spent this month.
  static int totalCents(HouseholdOverview o) => o.members.where((m) => m.sharing).fold(0, (a, m) => a + m.totalCents);

  static Map<String, int> byCategory(HouseholdOverview o) {
    final out = <String, int>{};
    for (final m in o.members.where((m) => m.sharing)) {
      m.categories.forEach((c, v) => out[c] = (out[c] ?? 0) + v);
    }
    return out;
  }

  static int sharingCount(HouseholdOverview o) => o.members.where((m) => m.sharing).length;
  static int notSharingCount(HouseholdOverview o) => o.members.where((m) => !m.sharing).length;

  static int? _budgetFor(HouseholdOverview o, String? category) =>
      o.budgets.where((b) => b.category == category).map((b) => b.amountCents).firstOrNull;

  /// The overall budget against everything shared, or null when no overall budget is set.
  static BudgetStatus? overall(HouseholdOverview o) {
    final b = _budgetFor(o, null);
    return b == null ? null : BudgetStatus(budgetCents: b, spentCents: totalCents(o));
  }

  /// Every category that has spending or a budget, biggest spend first (budgeted-but-unspent last).
  static List<CategoryLine> categoryLines(HouseholdOverview o) {
    final spent = byCategory(o);
    final names = {...spent.keys, for (final b in o.budgets) if (b.category != null) b.category!};
    final lines = [for (final n in names) CategoryLine(category: n, spentCents: spent[n] ?? 0, budgetCents: _budgetFor(o, n))];
    lines.sort((a, b) {
      final c = b.spentCents.compareTo(a.spentCents);
      return c != 0 ? c : a.category.toLowerCase().compareTo(b.category.toLowerCase());
    });
    return lines;
  }
}

/// What gets shared: monthly totals per category, never the individual expenses.
class SharedRow {
  const SharedRow({required this.month, required this.category, required this.cents});
  final DateTime month;
  final String category;
  final int cents;

  Map<String, Object> toJson() => {
        'month': '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01',
        'category': category,
        'spent': cents / 100,
      };
}

class SharedSummary {
  const SharedSummary({required this.from, required this.rows});

  /// First day of the earliest month included; the server replaces everything from here on.
  final DateTime from;
  final List<SharedRow> rows;
}

class SummaryBuilder {
  SummaryBuilder._();

  static const maxCategoryLength = 40;
  static const _maxRowsPerMonth = 60; // the server accepts 200 rows in all, over [monthsBack] + 1 months

  /// Turns local expenses into the monthly category totals to share: this month and [monthsBack] before it.
  /// Income is left out. Category names are shortened to what the server accepts, an empty name becomes "Other",
  /// and a month with an unusually long list of categories keeps its biggest ones and folds the rest into "Other".
  static SharedSummary build(Iterable<Expense> expenses, DateTime now, {int monthsBack = 2}) {
    final from = DateTime(now.year, now.month - monthsBack);
    final until = DateTime(now.year, now.month + 1);
    final perMonth = <DateTime, Map<String, int>>{};

    for (final e in expenses) {
      if (!e.isExpense || e.date.isBefore(from) || !e.date.isBefore(until)) continue;
      final month = DateTime(e.date.year, e.date.month);
      var name = e.category.name.trim();
      if (name.isEmpty) name = 'Other';
      if (name.length > maxCategoryLength) name = name.substring(0, maxCategoryLength).trim();
      final bucket = perMonth.putIfAbsent(month, () => {});
      bucket[name] = (bucket[name] ?? 0) + (e.amount * 100).round();
    }

    final rows = <SharedRow>[];
    final months = perMonth.keys.toList()..sort();
    for (final month in months) {
      final entries = perMonth[month]!.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
      var other = 0;
      for (var i = 0; i < entries.length; i++) {
        if (i < _maxRowsPerMonth - 1 || entries.length <= _maxRowsPerMonth) {
          rows.add(SharedRow(month: month, category: entries[i].key, cents: entries[i].value));
        } else {
          other += entries[i].value;
        }
      }
      if (other > 0) {
        final existing = rows.indexWhere((r) => r.month == month && r.category == 'Other');
        if (existing >= 0) {
          rows[existing] = SharedRow(month: month, category: 'Other', cents: rows[existing].cents + other);
        } else {
          rows.add(SharedRow(month: month, category: 'Other', cents: other));
        }
      }
    }
    return SharedSummary(from: from, rows: rows);
  }
}
