import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_provider.dart';
import '../widgets/expense_tile.dart';
import 'add_expense_screen.dart';

enum _DateRangePreset {
  all('All time'),
  thisMonth('This month'),
  lastMonth('Last month'),
  last3Months('Last 3 months'),
  thisYear('This year'),
  custom('Custom range');

  const _DateRangePreset(this.label);
  final String label;
}

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

// How many months' worth of grouped transactions to reveal at once —
// everything is already loaded locally, so this is purely about not
// dumping the whole history into one endless scroll, not a data-fetch
// limit. "Load more" reveals another batch of months rather than paging
// through an arbitrary row count, since transactions naturally cluster by
// month and that's a more meaningful unit to page by here.
const _monthsPerPage = 2;

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  String _query = '';
  _DateRangePreset _preset = _DateRangePreset.all;
  DateTimeRange? _customRange;
  final Set<int?> _selectedCategoryIds = {};
  int _visibleMonths = _monthsPerPage;

  int get _activeFilterCount =>
      (_query.isNotEmpty ? 1 : 0) +
      (_preset != _DateRangePreset.all ? 1 : 0) +
      (_selectedCategoryIds.isNotEmpty ? 1 : 0);

  DateTimeRange? get _resolvedRange {
    final now = DateTime.now();
    switch (_preset) {
      case _DateRangePreset.all:
        return null;
      case _DateRangePreset.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
      case _DateRangePreset.lastMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 1),
        );
      case _DateRangePreset.last3Months:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
      case _DateRangePreset.thisYear:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year + 1, 1, 1),
        );
      case _DateRangePreset.custom:
        return _customRange;
    }
  }

  List<Expense> _applyFilters(List<Expense> expenses) {
    var result = expenses;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      result = result.where((e) => e.title.toLowerCase().contains(q)).toList();
    }
    final range = _resolvedRange;
    if (range != null) {
      result = result
          .where((e) =>
              !e.date.isBefore(range.start) && e.date.isBefore(range.end))
          .toList();
    }
    if (_selectedCategoryIds.isNotEmpty) {
      result = result
          .where((e) => _selectedCategoryIds.contains(e.category.id))
          .toList();
    }
    return result;
  }

  Future<void> _openFilterSheet() async {
    final categories = context.read<CategoryProvider>().categories;
    var draftQuery = _query;
    var draftPreset = _preset;
    var draftRange = _customRange;
    final draftCategoryIds = {..._selectedCategoryIds};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filter transactions',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Vendor',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: draftQuery,
                      decoration: const InputDecoration(
                        hintText: 'Search by title',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => draftQuery = v,
                    ),
                    const SizedBox(height: 16),
                    const Text('Date range',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<_DateRangePreset>(
                      value: draftPreset,
                      items: _DateRangePreset.values
                          .map((p) => DropdownMenuItem(
                              value: p, child: Text(p.label)))
                          .toList(),
                      onChanged: (p) async {
                        if (p == null) return;
                        if (p == _DateRangePreset.custom) {
                          final picked = await showDateRangePicker(
                            context: sheetContext,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                            initialDateRange: draftRange,
                          );
                          if (picked != null) {
                            draftRange = picked;
                            setSheetState(() => draftPreset = p);
                          }
                        } else {
                          setSheetState(() => draftPreset = p);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Category',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((c) {
                        final selected = draftCategoryIds.contains(c.id);
                        return FilterChip(
                          label: Text(c.name),
                          avatar: Icon(c.icon, size: 16, color: c.color),
                          selected: selected,
                          onSelected: (v) => setSheetState(() {
                            if (v) {
                              draftCategoryIds.add(c.id);
                            } else {
                              draftCategoryIds.remove(c.id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                draftQuery = '';
                                draftPreset = _DateRangePreset.all;
                                draftRange = null;
                                draftCategoryIds.clear();
                              });
                            },
                            child: const Text('Clear all'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _query = draftQuery;
                                _preset = draftPreset;
                                _customRange = draftRange;
                                _selectedCategoryIds
                                  ..clear()
                                  ..addAll(draftCategoryIds);
                                // A new filter result set should start
                                // from the same "most recent 2 months"
                                // view, not stay expanded to however many
                                // months were revealed under the old
                                // filters.
                                _visibleMonths = _monthsPerPage;
                              });
                              Navigator.pop(sheetContext);
                            },
                            child: const Text('Apply filters'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _openFilterSheet,
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppTheme.accentColor,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_activeFilterCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          final filtered = _applyFilters(provider.expenses);
          return LoadingOverlay(
            isLoading: provider.isLoading,
            child: RefreshIndicator(
              onRefresh: provider.loadAll,
              child: filtered.isEmpty
                  ? ListView(
                      // RefreshIndicator needs a scrollable descendant even
                      // when there's nothing to show yet, or pull-to-refresh
                      // has no gesture surface to grab.
                      children: [
                        const SizedBox(height: 120),
                        EmptyState(
                          message: provider.expenses.isEmpty
                              ? 'No transactions yet.\nScan a receipt to start.'
                              : 'No transactions match your filters.',
                          icon: provider.expenses.isEmpty
                              ? Icons.document_scanner_outlined
                              : Icons.filter_alt_off_outlined,
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: _buildGroupedList(filtered, provider),
                    ),
            ),
          );
        },
      ),
    );
  }

  // Groups by calendar month (newest first, matching the provider's own
  // ordering) and only renders the most recently revealed _visibleMonths
  // of them — everything is already loaded locally, so this is purely a
  // "don't dump the whole history on screen at once" UI concern, not a
  // data-fetch limit like server-side pagination would be.
  List<Widget> _buildGroupedList(
      List<Expense> filtered, ExpenseProvider provider) {
    final grouped = <String, List<Expense>>{};
    for (final e in filtered) {
      final key = DateFormat.yMMMM().format(e.date);
      (grouped[key] ??= []).add(e);
    }
    final monthKeys = grouped.keys.toList();
    final visibleKeys = monthKeys.take(_visibleMonths).toList();
    final hasMore = monthKeys.length > _visibleMonths;

    final widgets = <Widget>[];
    for (var g = 0; g < visibleKeys.length; g++) {
      final key = visibleKeys[g];
      final monthNet = grouped[key]!.fold<double>(
          0, (sum, e) => sum + (e.isIncome ? e.amount : -e.amount));
      // space-y-xl (32px) between groups, but not before the very first
      // one (the ListView's own top padding already handles that edge).
      widgets.add(SizedBox(height: g == 0 ? 0 : 32));
      widgets.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // label-md: 12px/600 with the "tracking-wider" (0.05em)
          // override used on these section labels specifically.
          Text(
            key.toUpperCase(),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.6),
          ),
          Text(
            CurrencyFormatter.format(monthNet),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: monthNet < 0
                  ? AppTheme.expenseColor
                  : AppTheme.textSecondary,
            ),
          ),
        ],
      ));
      // mb-md (16px) between the header and its card.
      widgets.add(const SizedBox(height: 16));
      // One shared card per group with bordered rows inside, rather than
      // a separate card per transaction — matches the reference exactly,
      // including its specific 12px radius and soft diffused shadow
      // (rounded-xl + shadow-[0_20px_20px_0_rgba(0,0,0,0.04)]), which
      // differ from this app's global 16px/tinted Card theme.
      final monthExpenses = grouped[key]!;
      widgets.add(Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < monthExpenses.length; i++)
              ExpenseTile(
                expense: monthExpenses[i],
                showBottomBorder: i < monthExpenses.length - 1,
                onDelete: () => provider.remove(monthExpenses[i].id!),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddExpenseScreen(expense: monthExpenses[i]),
                  ),
                ),
              ),
          ],
        ),
      ));
    }
    if (hasMore) {
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: OutlinedButton(
          onPressed: () =>
              setState(() => _visibleMonths += _monthsPerPage),
          child: Text(
              'Load more (${monthKeys.length - _visibleMonths} more months)'),
        ),
      ));
    }
    return widgets;
  }
}
