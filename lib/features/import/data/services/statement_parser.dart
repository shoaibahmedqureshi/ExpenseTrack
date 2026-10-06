import '../../domain/entities/bank_statement.dart';

/// Thrown when the file can't be read as a statement at all.
class StatementParseException implements Exception {
  StatementParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when no known column layout matched; the UI lets the user pick columns.
class NeedsColumnMapping implements Exception {
  NeedsColumnMapping({required this.rows, required this.guessedHeaderRow});
  final List<List<String>> rows;
  final int guessedHeaderRow;
  @override
  String toString() => 'Could not recognise the columns in this file.';
}

/// Zero-based column indexes. Either [amount] or ([debit] and/or [credit]) is needed.
class ColumnMapping {
  const ColumnMapping({
    required this.headerRow,
    required this.date,
    this.description,
    this.debit,
    this.credit,
    this.amount,
    this.type,
    this.balance,
    this.reference,
  });

  final int headerRow;
  final int date;
  final int? description;
  final int? debit;
  final int? credit;
  final int? amount;
  final int? type;
  final int? balance;
  final int? reference;

  bool get hasAmount => amount != null || debit != null || credit != null;
}

class ParsedStatement {
  const ParsedStatement({
    required this.statement,
    required this.skippedRows,
    required this.dayFirst,
  });
  final BankStatement statement;
  final int skippedRows;
  final bool dayFirst;
}

/// Bank-agnostic CSV statement reader. All parsing happens on the device.
class StatementParser {
  StatementParser._();

  // ── CSV ────────────────────────────────────────────────────────────────

  /// RFC 4180 reader: quoted fields, escaped quotes, commas/newlines inside quotes.
  static List<List<String>> parseCsvRows(String text, {String? delimiter}) {
    var src = text;
    if (src.isNotEmpty && src.codeUnitAt(0) == 0xFEFF) src = src.substring(1);
    final d = delimiter ?? detectDelimiter(src);
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var fieldWasQuoted = false;

    void endField() {
      var v = field.toString();
      if (!fieldWasQuoted) v = v.trim();
      row.add(v);
      field.clear();
      fieldWasQuoted = false;
    }

    void endRow() {
      endField();
      if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    }

    for (var i = 0; i < src.length; i++) {
      final ch = src[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < src.length && src[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"' && field.toString().trim().isEmpty) {
        inQuotes = true;
        fieldWasQuoted = true;
        field.clear();
      } else if (ch == d) {
        endField();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < src.length && src[i + 1] == '\n') i++;
        endRow();
      } else {
        field.write(ch);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }

  /// Picks the delimiter that splits the first lines most consistently.
  static String detectDelimiter(String text) {
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).take(25).toList();
    String best = ',';
    var bestScore = -1;
    for (final d in [',', ';', '\t', '|']) {
      final counts = lines.map((l) => _countOutsideQuotes(l, d)).toList();
      final withAny = counts.where((c) => c > 0).toList();
      if (withAny.isEmpty) continue;
      // Most common non-zero count, weighted by how many lines share it.
      final freq = <int, int>{};
      for (final c in withAny) {
        freq[c] = (freq[c] ?? 0) + 1;
      }
      final top = freq.entries.reduce((a, b) => b.value > a.value ? b : a);
      final score = top.value * 10 + top.key;
      if (score > bestScore) {
        bestScore = score;
        best = d;
      }
    }
    return best;
  }

  static int _countOutsideQuotes(String line, String d) {
    var q = false, n = 0;
    for (var i = 0; i < line.length; i++) {
      if (line[i] == '"') q = !q;
      if (!q && line[i] == d) n++;
    }
    return n;
  }

  // ── Columns ────────────────────────────────────────────────────────────

  static String _norm(String h) =>
      h.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static const _dateNames = {
    'date', 'txn date', 'transaction date', 'trans date', 'tran date', 'posting date',
    'booking date', 'post date', 'value date', 'trn date',
  };
  static const _descNames = {
    'description', 'particulars', 'narration', 'details', 'transaction details',
    'transaction description', 'remarks', 'narrative', 'memo', 'payee', 'transaction',
    'detail', 'tran particulars',
  };
  static const _debitNames = {
    'debit', 'debits', 'withdrawal', 'withdrawals', 'dr', 'debit amount', 'amount debit',
    'paid out', 'money out', 'withdrawal amt', 'withdrawals amt', 'dr amount',
  };
  static const _creditNames = {
    'credit', 'credits', 'deposit', 'deposits', 'cr', 'credit amount', 'amount credit',
    'paid in', 'money in', 'deposit amt', 'deposits amt', 'cr amount',
  };
  static const _amountNames = {'amount', 'transaction amount', 'txn amount', 'amt', 'tran amount'};
  static const _typeNames = {
    'type', 'dr cr', 'cr dr', 'transaction type', 'debit credit', 'credit debit', 'd c',
    'txn type', 'dr cr indicator', 'indicator',
  };
  static const _balanceNames = {
    'balance', 'running balance', 'available balance', 'closing balance', 'bal',
    'ledger balance',
  };
  static const _refNames = {
    'reference', 'ref', 'ref no', 'reference no', 'reference number', 'cheque', 'cheque no',
    'chq no', 'chq', 'instrument', 'instrument no', 'transaction id', 'txn id', 'trans id',
    'utr',
  };

  /// Best-effort mapping for [header]; null when it doesn't look like a header row.
  static ColumnMapping? mapHeader(List<String> header, int headerRow) {
    int? date, desc, debit, credit, amount, type, balance, ref;
    int? valueDate;
    for (var i = 0; i < header.length; i++) {
      final h = _norm(header[i]);
      if (h.isEmpty) continue;
      if (_balanceNames.contains(h) || (h.contains('balance') && balance == null)) {
        balance ??= i;
      } else if (h == 'value date') {
        valueDate ??= i;
      } else if (_dateNames.contains(h)) {
        date ??= i;
      } else if (_debitNames.contains(h)) {
        debit ??= i;
      } else if (_creditNames.contains(h)) {
        credit ??= i;
      } else if (_amountNames.contains(h)) {
        amount ??= i;
      } else if (_typeNames.contains(h)) {
        type ??= i;
      } else if (_refNames.contains(h)) {
        ref ??= i;
      } else if (_descNames.contains(h)) {
        desc ??= i;
      } else if (h.contains('date')) {
        date ??= i;
      } else if (h.contains('withdraw') || h.startsWith('debit')) {
        debit ??= i;
      } else if (h.contains('deposit') || h.startsWith('credit')) {
        credit ??= i;
      } else if (h.contains('narration') || h.contains('particular') || h.contains('description')) {
        desc ??= i;
      } else if (h.contains('amount')) {
        amount ??= i;
      }
    }
    date ??= valueDate;
    if (date == null) return null;
    if (amount == null && debit == null && credit == null) return null;
    // Need something descriptive-looking or at least two other recognised columns.
    final recognised = [desc, debit, credit, amount, type, balance, ref].whereType<int>().length;
    if (recognised < 2) return null;
    return ColumnMapping(
      headerRow: headerRow,
      date: date,
      description: desc,
      debit: debit,
      credit: credit,
      amount: amount,
      type: type,
      balance: balance,
      reference: ref,
    );
  }

  static ColumnMapping? findMapping(List<List<String>> rows) {
    for (var i = 0; i < rows.length && i < 60; i++) {
      final m = mapHeader(rows[i], i);
      if (m != null) return m;
    }
    return null;
  }

  // ── Public entry points ────────────────────────────────────────────────

  static ParsedStatement parse(String csvText, {ColumnMapping? mapping}) {
    final rows = parseCsvRows(csvText);
    if (rows.length < 2) throw StatementParseException('The file is empty or has no transactions.');
    final m = mapping ?? findMapping(rows);
    if (m == null) {
      throw NeedsColumnMapping(rows: rows.take(40).toList(), guessedHeaderRow: _guessHeaderRow(rows));
    }
    return _build(rows, m);
  }

  static int _guessHeaderRow(List<List<String>> rows) {
    // First row with several non-empty cells followed by a row that contains a date.
    for (var i = 0; i < rows.length - 1 && i < 40; i++) {
      final filled = rows[i].where((c) => c.trim().isNotEmpty).length;
      if (filled >= 3 && rows[i].every((c) => parseStatementDate(c, dayFirst: true) == null)) {
        if (rows[i + 1].any((c) => parseStatementDate(c, dayFirst: true) != null)) return i;
      }
    }
    return 0;
  }

  // ── Dates ──────────────────────────────────────────────────────────────

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static int _year(int y) => y >= 100 ? y : (y < 70 ? 2000 + y : 1900 + y);

  static DateTime? _make(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(_year(y), m, d);
    return (dt.month == m && dt.day == d) ? dt : null;
  }

  /// Numeric d/m/y style where the day/month order is ambiguous.
  static final _numeric = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})(?!\d)');
  static final _iso = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)');
  static final _dMonY = RegExp(r'^(\d{1,2})[-/. ]+([A-Za-z]{3,9})[-/. ,]+(\d{2,4})(?!\d)');
  static final _monDY = RegExp(r'^([A-Za-z]{3,9})[-/. ]+(\d{1,2})(?:st|nd|rd|th)?,?[-/. ]+(\d{2,4})(?!\d)');

  static DateTime? parseStatementDate(String raw, {required bool dayFirst}) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    var m = _iso.firstMatch(s);
    if (m != null) return _make(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    m = _dMonY.firstMatch(s);
    if (m != null) {
      final mon = _months[m[2]!.toLowerCase().substring(0, 3)];
      if (mon != null) return _make(int.parse(m[3]!), mon, int.parse(m[1]!));
    }
    m = _monDY.firstMatch(s);
    if (m != null) {
      final mon = _months[m[1]!.toLowerCase().substring(0, 3)];
      if (mon != null) return _make(int.parse(m[3]!), mon, int.parse(m[2]!));
    }
    m = _numeric.firstMatch(s);
    if (m != null) {
      final a = int.parse(m[1]!), b = int.parse(m[2]!), y = int.parse(m[3]!);
      return dayFirst ? _make(y, b, a) : _make(y, a, b);
    }
    return null;
  }

  /// True unless the file proves month-first (some second number is above 12).
  static bool detectDayFirst(Iterable<String> dateCells) {
    var sawFirstOver12 = false, sawSecondOver12 = false;
    for (final c in dateCells) {
      final m = _numeric.firstMatch(c.trim());
      if (m == null) continue;
      if (int.parse(m[1]!) > 12) sawFirstOver12 = true;
      if (int.parse(m[2]!) > 12) sawSecondOver12 = true;
    }
    if (sawFirstOver12) return true;
    if (sawSecondOver12) return false;
    return true;
  }

  // ── Amounts ────────────────────────────────────────────────────────────

  /// Returns the signed value (negative for "(1,000)", "-1,000", "1,000-") and
  /// whether a DR / CR marker was attached. Null when there's no number.
  static ({double value, bool? isDebit})? parseStatementAmount(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return null;
    var negative = false;
    bool? isDebit;

    if (t.startsWith('(') && t.endsWith(')')) {
      negative = true;
      t = t.substring(1, t.length - 1);
    }
    final suffix = RegExp(r'([\d.,\s])(DR|CR)\.?\s*$', caseSensitive: false).firstMatch(t);
    if (suffix != null) {
      isDebit = suffix[2]!.toUpperCase() == 'DR';
      t = t.substring(0, suffix.start + 1).trim();
    }
    final lead = RegExp(r'^(DR|CR)\.?\s+', caseSensitive: false).firstMatch(t);
    if (lead != null) {
      isDebit = lead[1]!.toUpperCase() == 'DR';
      t = t.substring(lead.end);
    }
    t = t.replaceAll(RegExp(r'(PKR|RS\.?|USD|AED|GBP|EUR|SAR|₨|\$|£|€)', caseSensitive: false), '').trim();
    if (t.startsWith('-') || t.startsWith('−')) {
      negative = true;
      t = t.substring(1);
    }
    if (t.endsWith('-')) {
      negative = true;
      t = t.substring(0, t.length - 1);
    }
    t = t.replaceAll(RegExp(r'[^\d.,]'), '');
    if (t.isEmpty || !RegExp(r'\d').hasMatch(t)) return null;

    final lastDot = t.lastIndexOf('.');
    final lastComma = t.lastIndexOf(',');
    String normalized;
    if (lastDot >= 0 && lastComma >= 0) {
      normalized = lastDot > lastComma
          ? t.replaceAll(',', '')
          : t.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastComma >= 0) {
      final after = t.length - lastComma - 1;
      final multiple = ','.allMatches(t).length > 1;
      normalized = (multiple || after == 3) ? t.replaceAll(',', '') : t.replaceAll(',', '.');
    } else if (lastDot >= 0) {
      normalized = '.'.allMatches(t).length > 1 ? t.replaceAll('.', '') : t;
    } else {
      normalized = t;
    }
    final v = double.tryParse(normalized);
    if (v == null) return null;
    return (value: negative ? -v : v, isDebit: isDebit);
  }

  // ── Building the statement ─────────────────────────────────────────────

  static String _cell(List<String> r, int? i) => (i != null && i < r.length) ? r[i].trim() : '';

  static bool? _typeFromText(String t) {
    final s = t.trim().toLowerCase();
    if (s.isEmpty) return null;
    if (const {'dr', 'debit', 'd', 'withdrawal', 'w', 'debited', 'dr.'}.contains(s) || s.startsWith('debit')) return true;
    if (const {'cr', 'credit', 'c', 'deposit', 'credited', 'cr.'}.contains(s) || s.startsWith('credit')) return false;
    return null;
  }

  static ParsedStatement _build(List<List<String>> rows, ColumnMapping m) {
    final dataRows = rows.skip(m.headerRow + 1).toList();
    final dateCells = dataRows.map((r) => _cell(r, m.date));
    final dayFirst = detectDayFirst(dateCells);

    final raw = <_Raw>[];
    var skipped = 0;
    for (final r in dataRows) {
      final date = parseStatementDate(_cell(r, m.date), dayFirst: dayFirst);
      if (date == null) {
        skipped++;
        continue;
      }
      double? amount;
      bool? isDebit;

      final dTxt = _cell(r, m.debit), cTxt = _cell(r, m.credit);
      if (m.debit != null || m.credit != null) {
        final d = parseStatementAmount(dTxt)?.value.abs() ?? 0;
        final c = parseStatementAmount(cTxt)?.value.abs() ?? 0;
        if (d > 0 && c == 0) {
          amount = d;
          isDebit = true;
        } else if (c > 0 && d == 0) {
          amount = c;
          isDebit = false;
        } else if (d > 0 && c > 0) {
          // Both populated: treat the larger as the movement.
          amount = (d - c).abs();
          isDebit = d > c;
        }
      }
      if (amount == null && m.amount != null) {
        final p = parseStatementAmount(_cell(r, m.amount));
        if (p != null && p.value != 0) {
          amount = p.value.abs();
          isDebit = _typeFromText(_cell(r, m.type)) ?? p.isDebit ?? (p.value < 0 ? true : null);
        }
      }
      if (amount == null || amount == 0) {
        skipped++;
        continue;
      }
      final bal = m.balance == null ? null : parseStatementAmount(_cell(r, m.balance))?.value;
      raw.add(_Raw(
        date: date,
        description: _cell(r, m.description),
        amount: amount,
        isDebit: isDebit,
        balance: bal,
        reference: _cell(r, m.reference).isEmpty ? null : _cell(r, m.reference),
      ));
    }
    if (raw.isEmpty) {
      throw StatementParseException(
          'No transactions were found. Check that the file is a bank statement export with a date and amount for each row.');
    }

    // Chronological order (many banks list newest first).
    if (raw.first.date.isAfter(raw.last.date)) {
      raw.setAll(0, raw.reversed.toList());
    }

    // Rows without an explicit direction: use the running balance, else assume
    // a positive amount is a credit.
    for (var i = 0; i < raw.length; i++) {
      if (raw[i].isDebit != null) continue;
      final bal = raw[i].balance;
      double? prev = i > 0 ? raw[i - 1].balance : null;
      if (bal != null && prev != null) {
        raw[i].isDebit = (bal - prev) < 0;
      } else if (bal != null && i + 1 < raw.length && raw[i + 1].balance != null && raw[i + 1].isDebit != null) {
        final next = raw[i + 1];
        final nextSigned = next.isDebit! ? -next.amount : next.amount;
        final before = next.balance! - nextSigned; // balance right after row i
        raw[i].isDebit = false;
        if (i > 0 && raw[i - 1].balance != null) raw[i].isDebit = (before - raw[i - 1].balance!) < 0;
      } else {
        raw[i].isDebit = false;
      }
    }

    final txns = [
      for (final r in raw)
        BankStatementTransaction(
          date: r.date,
          description: r.description.isEmpty ? (r.isDebit! ? 'Debit' : 'Credit') : r.description,
          amount: r.amount,
          reference: r.reference,
          type: r.isDebit! ? 'debit' : 'credit',
        ),
    ];

    double opening = 0, closing = 0;
    final first = raw.first, last = raw.last;
    if (first.balance != null) {
      final signed = first.isDebit! ? -first.amount : first.amount;
      opening = first.balance! - signed;
    }
    if (last.balance != null) closing = last.balance!;

    final preamble = rows.take(m.headerRow).map((r) => r.join(' ')).join('\n');
    final dates = txns.map((t) => t.date);
    return ParsedStatement(
      statement: BankStatement(
        bankName: detectBank(preamble),
        accountNumber: detectAccount(preamble),
        periodStart: dates.reduce((a, b) => a.isBefore(b) ? a : b),
        periodEnd: dates.reduce((a, b) => a.isAfter(b) ? a : b),
        transactions: txns,
        openingBalance: opening,
        closingBalance: closing,
      ),
      skippedRows: skipped,
      dayFirst: dayFirst,
    );
  }

  // ── Bank / account hints (display only) ────────────────────────────────

  static const _banks = <(String, String)>[
    ('habib bank', 'HBL'), ('hbl', 'HBL'), ('meezan', 'Meezan Bank'), ('mcb', 'MCB Bank'),
    ('muslim commercial', 'MCB Bank'), ('united bank', 'UBL'), ('ubl', 'UBL'),
    ('allied bank', 'Allied Bank'), ('alfalah', 'Bank Alfalah'), ('faysal', 'Faysal Bank'),
    ('standard chartered', 'Standard Chartered'), ('askari', 'Askari Bank'),
    ('soneri', 'Soneri Bank'), ('bankislami', 'BankIslami'), ('bank islami', 'BankIslami'),
    ('national bank', 'National Bank of Pakistan'), ('js bank', 'JS Bank'),
    ('bank al habib', 'Bank AL Habib'), ('easypaisa', 'Easypaisa'), ('jazzcash', 'JazzCash'),
    ('sadapay', 'SadaPay'), ('nayapay', 'NayaPay'),
  ];

  static String detectBank(String preamble) {
    final lower = preamble.toLowerCase();
    for (final (key, name) in _banks) {
      if (RegExp('(^|[^a-z])${RegExp.escape(key)}([^a-z]|\$)').hasMatch(lower)) return name;
    }
    return 'Bank statement';
  }

  static String detectAccount(String preamble) {
    final m = RegExp(r'(?:a/?c|account)[^\n\d]{0,25}([\d][\d\- ]{5,30}\d)', caseSensitive: false).firstMatch(preamble);
    if (m == null) return '';
    final digits = m[1]!.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length >= 4 ? '••••${digits.substring(digits.length - 4)}' : '';
  }
}

class _Raw {
  _Raw({
    required this.date,
    required this.description,
    required this.amount,
    required this.isDebit,
    required this.balance,
    required this.reference,
  });
  final DateTime date;
  final String description;
  final double amount;
  bool? isDebit;
  final double? balance;
  final String? reference;
}
