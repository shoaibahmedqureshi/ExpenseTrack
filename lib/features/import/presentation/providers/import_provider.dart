import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../categories/domain/entities/category.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../../data/services/duplicate_detector.dart';
import '../../data/services/statement_categorizer.dart';
import '../../data/services/statement_parser.dart';
import '../../domain/entities/bank_statement.dart';

enum ImportStage { idle, parsing, needsMapping, preview, importing, done }

class ImportRow {
  ImportRow({required this.txn, required this.category, required this.selected, this.duplicateNote, this.possibleDuplicate = false});
  final BankStatementTransaction txn;
  String category;
  bool selected;
  final String? duplicateNote;
  final bool possibleDuplicate;
}

class ImportProvider extends ChangeNotifier {
  ImportStage _stage = ImportStage.idle;
  String? _error;
  String? _fileName;
  String? _rawText;
  List<List<String>> _mappingRows = const [];
  int _guessedHeaderRow = 0;
  ParsedStatement? _parsed;
  List<ImportRow> _rows = [];
  List<Expense> _existing = const [];
  List<String> _categoryNames = const [];
  ({int imported, int failed})? _result;

  ImportStage get stage => _stage;
  String? get error => _error;
  String? get fileName => _fileName;
  List<List<String>> get mappingRows => _mappingRows;
  int get guessedHeaderRow => _guessedHeaderRow;
  BankStatement? get statement => _parsed?.statement;
  int get skippedRows => _parsed?.skippedRows ?? 0;
  List<ImportRow> get rows => _rows;
  List<String> get categoryNames => _categoryNames;
  ({int imported, int failed})? get result => _result;

  int get selectedCount => _rows.where((r) => r.selected).length;
  int get duplicateCount => _rows.where((r) => !r.selected && r.duplicateNote != null).length;
  double get selectedExpenseTotal =>
      _rows.where((r) => r.selected && r.txn.isExpense).fold(0.0, (a, r) => a + r.txn.amount);
  double get selectedIncomeTotal =>
      _rows.where((r) => r.selected && !r.txn.isExpense).fold(0.0, (a, r) => a + r.txn.amount);

  /// Reads a CSV from disk (UTF-8, falling back to Latin-1) and parses it.
  Future<void> loadFile(String path, {required List<Expense> existing, required List<Category> categories}) async {
    _begin(path.split(Platform.pathSeparator).last, existing, categories);
    try {
      final bytes = await File(path).readAsBytes();
      String text;
      try {
        text = utf8.decode(bytes);
      } on FormatException {
        text = latin1.decode(bytes);
      }
      loadText(text, fileName: _fileName, existing: existing, categories: categories);
    } catch (e) {
      _fail('Could not read the file: $e');
    }
  }

  /// Parses already-loaded CSV text. Public so tests (and mapping retries) can use it.
  void loadText(String text, {String? fileName, required List<Expense> existing, required List<Category> categories, ColumnMapping? mapping}) {
    if (mapping == null) _begin(fileName ?? _fileName, existing, categories);
    _rawText = text;
    try {
      _parsed = StatementParser.parse(text, mapping: mapping);
      _buildRows();
      _stage = ImportStage.preview;
      notifyListeners();
    } on NeedsColumnMapping catch (e) {
      _mappingRows = e.rows;
      _guessedHeaderRow = e.guessedHeaderRow;
      _stage = ImportStage.needsMapping;
      notifyListeners();
    } on StatementParseException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('This file could not be read as a bank statement: $e');
    }
  }

  void applyMapping(ColumnMapping mapping) {
    final text = _rawText;
    if (text == null) return;
    _error = null;
    loadText(text, existing: _existing, categories: const [], mapping: mapping);
  }

  void _begin(String? fileName, List<Expense> existing, List<Category> categories) {
    _stage = ImportStage.parsing;
    _error = null;
    _fileName = fileName;
    _parsed = null;
    _rows = [];
    _result = null;
    _existing = existing;
    _categoryNames = categories.map((c) => c.name).toList();
    notifyListeners();
  }

  void _fail(String message) {
    _error = message;
    _stage = ImportStage.idle;
    notifyListeners();
  }

  String get _fallbackCategory {
    for (final n in _categoryNames) {
      if (n.toLowerCase() == 'other') return n;
    }
    return _categoryNames.isNotEmpty ? _categoryNames.first : 'Other';
  }

  void _buildRows() {
    final statement = _parsed!.statement;
    final claimed = <Expense>{};
    final rows = <ImportRow>[];
    for (final t in statement.transactions) {
      DuplicateDetectionResult? best;
      for (final m in DuplicateDetector.findDuplicates(t, _existing)) {
        final e = m.matchedExpense;
        if (e == null || claimed.contains(e) || e.isExpense != t.isExpense) continue;
        best = m;
        break;
      }
      var selected = true, possible = false;
      String? note;
      if (best != null) {
        if (best.isDuplicate) {
          claimed.add(best.matchedExpense!);
          selected = false;
          note = 'Already recorded: ${best.reason}';
        } else if (best.confidenceScore >= 0.5) {
          possible = true;
          note = 'Possible duplicate: ${best.reason}';
        }
      }
      rows.add(ImportRow(
        txn: t,
        category: StatementCategorizer.suggest(t.description, isExpense: t.isExpense, available: _categoryNames) ?? _fallbackCategory,
        selected: selected,
        duplicateNote: note,
        possibleDuplicate: possible,
      ));
    }
    _rows = rows;
  }

  void toggle(int i) {
    _rows[i].selected = !_rows[i].selected;
    notifyListeners();
  }

  void setAll(bool selected) {
    for (final r in _rows) {
      r.selected = selected;
    }
    notifyListeners();
  }

  void setCategory(int i, String name) {
    _rows[i].category = name;
    notifyListeners();
  }

  /// Saves the selected rows as expenses/income. Returns how many were saved.
  Future<int> importSelected(ExpenseProvider expenses, List<Category> categories) async {
    final byName = {for (final c in categories) c.name.toLowerCase(): c};
    final bank = statement?.bankName ?? 'bank statement';
    final toSave = <Expense>[];
    for (final r in _rows.where((r) => r.selected)) {
      final cat = byName[r.category.toLowerCase()] ?? (categories.isNotEmpty ? categories.first : null);
      if (cat == null) continue;
      final t = r.txn;
      toSave.add(Expense(
        title: t.description.length > 80 ? t.description.substring(0, 80) : t.description,
        amount: t.amount,
        date: t.date,
        type: t.isExpense ? TransactionType.expense : TransactionType.income,
        category: cat,
        note: 'Imported from $bank${t.reference != null ? ' · ref ${t.reference}' : ''}',
      ));
    }
    _stage = ImportStage.importing;
    notifyListeners();
    final saved = await expenses.addAll(toSave);
    _result = (imported: saved, failed: toSave.length - saved);
    _stage = ImportStage.done;
    notifyListeners();
    return saved;
  }

  void reset() {
    _stage = ImportStage.idle;
    _error = null;
    _fileName = null;
    _rawText = null;
    _mappingRows = const [];
    _parsed = null;
    _rows = [];
    _result = null;
    notifyListeners();
  }
}
