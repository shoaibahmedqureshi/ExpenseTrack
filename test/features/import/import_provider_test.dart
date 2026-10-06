import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/categories/domain/entities/category.dart';
import 'package:outlay/features/expenses/domain/entities/expense.dart';
import 'package:outlay/features/expenses/domain/repositories/expense_repository.dart';
import 'package:outlay/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:outlay/features/expenses/domain/usecases/manage_expense_usecase.dart';
import 'package:outlay/features/expenses/presentation/providers/expense_provider.dart';
import 'package:outlay/features/import/data/services/statement_parser.dart';
import 'package:outlay/features/import/presentation/providers/import_provider.dart';

/// In-memory stand-in: only insert/getAll are exercised.
class _MemoryRepo implements ExpenseRepository {
  final saved = <Expense>[];
  int failAfter = 1 << 30;
  @override
  Future<int> insert(Expense e) async {
    if (saved.length >= failAfter) throw Exception('disk full');
    saved.add(e);
    return saved.length;
  }

  @override
  Future<List<Expense>> getAll() async => saved;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

Category _c(int id, String n) => Category(id: id, name: n, icon: Icons.category, color: Colors.blue);

final _cats = [_c(1, 'Food'), _c(2, 'Transport'), _c(3, 'Salary'), _c(4, 'Other')];

const _csv = '''Habib Bank Limited
Date,Description,Debit,Credit,Balance
02/10/2026,IMTIAZ SUPER MARKET,"4,500.00",,95500
03/10/2026,CAREEM RIDE,850.00,,94650
05/10/2026,SALARY OCT,,150000,244650
06/10/2026,UNKNOWN IBFT,1200.00,,243450
''';

Expense _existing(String t, double a, DateTime d, {bool income = false}) => Expense(
    id: 99, title: t, amount: a, date: d,
    type: income ? TransactionType.income : TransactionType.expense, category: _cats[0]);

void main() {
  group('previewing', () {
    test('suggests categories and falls back to Other', () {
      final p = ImportProvider();
      p.loadText(_csv, existing: const [], categories: _cats);
      expect(p.stage, ImportStage.preview);
      expect(p.rows.map((r) => r.category).toList(), ['Food', 'Transport', 'Salary', 'Other']);
      expect(p.selectedCount, 4);
      expect(p.selectedExpenseTotal, 6550);
      expect(p.selectedIncomeTotal, 150000);
    });

    test('flags rows already recorded and deselects them', () {
      final p = ImportProvider();
      p.loadText(_csv,
          existing: [_existing('Imtiaz', 4500, DateTime(2026, 10, 2))], categories: _cats);
      expect(p.rows[0].selected, isFalse);
      expect(p.rows[0].duplicateNote, startsWith('Already recorded'));
      expect(p.duplicateCount, 1);
      expect(p.selectedCount, 3);
    });

    test('one existing expense only absorbs one statement row', () {
      const twoCoffees = '''Date,Description,Debit,Credit
05/10/2026,COFFEE,350,
05/10/2026,COFFEE,350,
''';
      final p = ImportProvider();
      p.loadText(twoCoffees,
          existing: [_existing('Coffee', 350, DateTime(2026, 10, 5))], categories: _cats);
      expect(p.rows.map((r) => r.selected).toList(), [false, true]);
    });

    test('an income row is never matched against an expense', () {
      const csv = 'Date,Description,Debit,Credit\n05/10/2026,Refund,,350\n';
      final p = ImportProvider();
      p.loadText(csv, existing: [_existing('Coffee', 350, DateTime(2026, 10, 5))], categories: _cats);
      expect(p.rows.single.selected, isTrue);
    });

    test('unknown layout waits for a column mapping, then previews', () {
      const csv = 'When,What,How much\n01/10/2026,Coffee,350\n';
      final p = ImportProvider();
      p.loadText(csv, existing: const [], categories: _cats);
      expect(p.stage, ImportStage.needsMapping);
      p.applyMapping(const ColumnMapping(headerRow: 0, date: 0, description: 1, amount: 2));
      expect(p.stage, ImportStage.preview);
      expect(p.rows.single.txn.amount, 350);
    });

    test('a bad file reports a readable error and stays idle', () {
      final p = ImportProvider();
      p.loadText('just one line', existing: const [], categories: _cats);
      expect(p.stage, ImportStage.idle);
      expect(p.error, isNotNull);
    });
  });

  group('importing', () {
    ExpenseProvider providerFor(_MemoryRepo r) =>
        ExpenseProvider(getExpenses: GetExpensesUsecase(r), manageExpense: ManageExpenseUsecase(r));

    test('saves only selected rows as expenses/income with category and note', () async {
      final repo = _MemoryRepo();
      final ep = providerFor(repo);
      final p = ImportProvider();
      p.loadText(_csv, existing: const [], categories: _cats);
      p.toggle(3); // drop the unknown IBFT row
      p.setCategory(1, 'Food'); // user override
      final n = await p.importSelected(ep, _cats);

      expect(n, 3);
      expect(p.stage, ImportStage.done);
      expect(repo.saved.map((e) => e.title).toList(),
          ['IMTIAZ SUPER MARKET', 'CAREEM RIDE', 'SALARY OCT']);
      expect(repo.saved[1].category.name, 'Food');
      expect(repo.saved[2].type, TransactionType.income);
      expect(repo.saved[0].note, contains('Imported from HBL'));
      expect(ep.expenses.length, 3);
    });

    test('reports partial failure and keeps what was saved', () async {
      final repo = _MemoryRepo()..failAfter = 2;
      final ep = providerFor(repo);
      final p = ImportProvider();
      p.loadText(_csv, existing: const [], categories: _cats);
      final n = await p.importSelected(ep, _cats);
      expect(n, 2);
      expect(p.result!.imported, 2);
      expect(p.result!.failed, 2);
      expect(ep.error, isNotNull);
    });
  });
}
