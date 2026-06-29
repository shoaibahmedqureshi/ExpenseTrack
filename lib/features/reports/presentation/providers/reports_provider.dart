import 'package:flutter/foundation.dart' hide Category;

import '../../../categories/domain/entities/category.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/domain/usecases/get_expenses_usecase.dart';

enum ReportPeriod { daily, weekly, monthly }

class CategoryTotal {
  const CategoryTotal({
    required this.category,
    required this.total,
    required this.percent,
  });

  final Category category;
  final double total;
  final double percent;
}

class ChartBucket {
  const ChartBucket({
    required this.label,
    required this.income,
    required this.expense,
  });

  final String label;
  final double income;
  final double expense;
}

class ReportsProvider extends ChangeNotifier {
  ReportsProvider({required GetExpensesUsecase getExpenses})
      : _getExpenses = getExpenses;

  final GetExpensesUsecase _getExpenses;

  ReportPeriod _period = ReportPeriod.monthly;
  DateTime _anchor = DateTime.now();
  TransactionType? _typeFilter;
  Category? _categoryFilter;

  List<Expense> _periodExpenses = [];
  bool _isLoading = false;
  String? _error;

  ReportPeriod get period => _period;
  DateTime get anchor => _anchor;
  TransactionType? get typeFilter => _typeFilter;
  Category? get categoryFilter => _categoryFilter;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Expense> get filteredExpenses => _periodExpenses
      .where((e) => _typeFilter == null || e.type == _typeFilter)
      .where(
          (e) => _categoryFilter == null || e.category.id == _categoryFilter!.id)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  double get totalIncome => filteredExpenses
      .where((e) => e.isIncome)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get totalExpense => filteredExpenses
      .where((e) => e.isExpense)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get net => totalIncome - totalExpense;

  (DateTime, DateTime) get range => _rangeFor(_period, _anchor);

  static (DateTime, DateTime) _rangeFor(ReportPeriod period, DateTime anchor) {
    switch (period) {
      case ReportPeriod.daily:
        final start = DateTime(anchor.year, anchor.month, anchor.day);
        return (start, start.add(const Duration(days: 1)));
      case ReportPeriod.weekly:
        final start = DateTime(anchor.year, anchor.month, anchor.day)
            .subtract(Duration(days: anchor.weekday - 1));
        return (start, start.add(const Duration(days: 7)));
      case ReportPeriod.monthly:
        final start = DateTime(anchor.year, anchor.month, 1);
        final end = DateTime(anchor.year, anchor.month + 1, 1);
        return (start, end);
    }
  }

  String get periodLabel {
    final (start, end) = range;
    switch (_period) {
      case ReportPeriod.daily:
        return '${_monthDay(start)}, ${start.year}';
      case ReportPeriod.weekly:
        final lastDay = end.subtract(const Duration(days: 1));
        if (start.month == lastDay.month) {
          return '${_monthDay(start)} – ${lastDay.day}, ${start.year}';
        }
        return '${_monthDay(start)} – ${_monthDay(lastDay)}, ${start.year}';
      case ReportPeriod.monthly:
        return '${_monthName(start.month)} ${start.year}';
    }
  }

  static String _monthDay(DateTime d) => '${_monthName(d.month)} ${d.day}';

  static String _monthName(int month) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][month - 1];

  List<CategoryTotal> get categoryBreakdown {
    final expenseOnly = filteredExpenses.where((e) => e.isExpense).toList();
    final total = expenseOnly.fold(0.0, (sum, e) => sum + e.amount);
    if (total == 0) return [];

    final byCategory = <int, double>{};
    final categoryById = <int, Category>{};
    for (final e in expenseOnly) {
      final id = e.category.id ?? -1;
      byCategory[id] = (byCategory[id] ?? 0) + e.amount;
      categoryById[id] = e.category;
    }

    final result = byCategory.entries
        .map((entry) => CategoryTotal(
              category: categoryById[entry.key]!,
              total: entry.value,
              percent: entry.value / total,
            ))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return result;
  }

  List<ChartBucket> get chartBuckets {
    final (start, end) = range;
    switch (_period) {
      case ReportPeriod.daily:
        return _hourlyBuckets(start);
      case ReportPeriod.weekly:
        return _dailyBuckets(start, end, labelWeekday: true);
      case ReportPeriod.monthly:
        return _dailyBuckets(start, end, labelWeekday: false);
    }
  }

  List<ChartBucket> _hourlyBuckets(DateTime dayStart) {
    const labels = ['12am', '4am', '8am', '12pm', '4pm', '8pm'];
    final buckets = List.generate(6, (i) => (income: 0.0, expense: 0.0));
    for (final e in filteredExpenses) {
      final slot = (e.date.hour ~/ 4).clamp(0, 5);
      final b = buckets[slot];
      buckets[slot] = e.isIncome
          ? (income: b.income + e.amount, expense: b.expense)
          : (income: b.income, expense: b.expense + e.amount);
    }
    return List.generate(
      6,
      (i) => ChartBucket(
        label: labels[i],
        income: buckets[i].income,
        expense: buckets[i].expense,
      ),
    );
  }

  List<ChartBucket> _dailyBuckets(DateTime start, DateTime end,
      {required bool labelWeekday}) {
    final dayCount = end.difference(start).inDays;
    final buckets = List.generate(dayCount, (i) => (income: 0.0, expense: 0.0));
    for (final e in filteredExpenses) {
      final dayIndex = DateTime(e.date.year, e.date.month, e.date.day)
          .difference(start)
          .inDays;
      if (dayIndex < 0 || dayIndex >= dayCount) continue;
      final b = buckets[dayIndex];
      buckets[dayIndex] = e.isIncome
          ? (income: b.income + e.amount, expense: b.expense)
          : (income: b.income, expense: b.expense + e.amount);
    }
    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(dayCount, (i) {
      final day = start.add(Duration(days: i));
      final label = labelWeekday ? weekdayLabels[i] : '${day.day}';
      return ChartBucket(
        label: label,
        income: buckets[i].income,
        expense: buckets[i].expense,
      );
    });
  }

  void setPeriod(ReportPeriod period) {
    if (_period == period) return;
    _period = period;
    load();
  }

  void setTypeFilter(TransactionType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  void setCategoryFilter(Category? category) {
    _categoryFilter = category;
    notifyListeners();
  }

  void previousPeriod() {
    _anchor = switch (_period) {
      ReportPeriod.daily => _anchor.subtract(const Duration(days: 1)),
      ReportPeriod.weekly => _anchor.subtract(const Duration(days: 7)),
      ReportPeriod.monthly =>
        DateTime(_anchor.year, _anchor.month - 1, _anchor.day),
    };
    load();
  }

  void nextPeriod() {
    _anchor = switch (_period) {
      ReportPeriod.daily => _anchor.add(const Duration(days: 1)),
      ReportPeriod.weekly => _anchor.add(const Duration(days: 7)),
      ReportPeriod.monthly =>
        DateTime(_anchor.year, _anchor.month + 1, _anchor.day),
    };
    load();
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final (start, end) = range;
      _periodExpenses = await _getExpenses.byDateRange(start, end);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
