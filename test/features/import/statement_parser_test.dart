import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/import/data/services/statement_parser.dart';

void main() {
  group('parseCsvRows', () {
    test('handles quoted commas, escaped quotes and embedded newlines', () {
      final rows = StatementParser.parseCsvRows(
          'a,b,c\r\n"x, y","say ""hi""","line1\nline2"\r\n');
      expect(rows[1], ['x, y', 'say "hi"', 'line1\nline2']);
    });
    test('strips a BOM and skips blank lines', () {
      final rows = StatementParser.parseCsvRows('﻿Date,Amount\n\n01/01/2026,5\n');
      expect(rows.length, 2);
      expect(rows[0][0], 'Date');
    });
    test('detects semicolons and tabs', () {
      expect(StatementParser.detectDelimiter('Date;Debit;Credit\n01/02/2026;5;0\n'), ';');
      expect(StatementParser.detectDelimiter('Date\tDebit\tCredit\n01/02/2026\t5\t0\n'), '\t');
      expect(StatementParser.detectDelimiter('Date,Debit,Credit\n01/02/2026,5,0\n'), ',');
    });
  });

  group('parseStatementAmount', () {
    ({double value, bool? isDebit})? p(String s) => StatementParser.parseStatementAmount(s);
    test('plain and thousands', () {
      expect(p('1,234.56')!.value, 1234.56);
      expect(p('Rs. 12,500')!.value, 12500);
      expect(p('PKR 1,00,000.00')!.value, 100000);
      expect(p('500')!.value, 500);
    });
    test('negatives', () {
      expect(p('(1,000.00)')!.value, -1000);
      expect(p('-250.50')!.value, -250.5);
      expect(p('250.50-')!.value, -250.5);
    });
    test('DR/CR markers', () {
      final dr = p('1,500.00 Dr')!;
      expect(dr.value, 1500);
      expect(dr.isDebit, isTrue);
      final cr = p('2,000.00CR')!;
      expect(cr.value, 2000);
      expect(cr.isDebit, isFalse);
    });
    test('european separators', () {
      expect(p('1.234,56')!.value, 1234.56);
      expect(p('12,50')!.value, 12.5);
      expect(p('1,234')!.value, 1234);
    });
    test('not an amount', () {
      expect(p(''), isNull);
      expect(p('n/a'), isNull);
      expect(p('---'), isNull);
    });
  });

  group('dates', () {
    DateTime? d(String s, {bool dayFirst = true}) =>
        StatementParser.parseStatementDate(s, dayFirst: dayFirst);
    test('numeric day-first and month-first', () {
      expect(d('05/10/2026'), DateTime(2026, 10, 5));
      expect(d('05/10/2026', dayFirst: false), DateTime(2026, 5, 10));
      expect(d('31-12-2025'), DateTime(2025, 12, 31));
    });
    test('textual months', () {
      expect(d('05-Oct-2026'), DateTime(2026, 10, 5));
      expect(d('5 October 2026'), DateTime(2026, 10, 5));
      expect(d('Oct 5, 2026'), DateTime(2026, 10, 5));
      expect(d('05-Sept-26'), DateTime(2026, 9, 5));
    });
    test('iso with time suffix', () {
      expect(d('2026-10-05 14:32:11'), DateTime(2026, 10, 5));
    });
    test('rejects impossible dates and text', () {
      expect(d('31/02/2026'), isNull);
      expect(d('hello'), isNull);
      expect(d('13/13/2026'), isNull);
    });
    test('day-first is detected from the data', () {
      expect(StatementParser.detectDayFirst(['13/01/2026', '02/03/2026']), isTrue);
      expect(StatementParser.detectDayFirst(['01/13/2026', '02/03/2026']), isFalse);
      expect(StatementParser.detectDayFirst(['01/02/2026']), isTrue);
    });
  });

  group('HBL-style: preamble, debit/credit columns, quoted commas', () {
    const csv = '''Habib Bank Limited
Account Title: SHOAIB AHMED
Account No: 1234-5678901-03
Statement Period: 01/10/2026 to 31/10/2026

Date,Description,Debit,Credit,Balance
01/10/2026,"Opening forward",,,"100,000.00"
02/10/2026,"POS PURCHASE IMTIAZ SUPER MARKET, DHA","4,500.00",,"95,500.00"
05/10/2026,"SALARY OCT 2026",,"150,000.00","245,500.00"
13/10/2026,"ATM WITHDRAWAL",20000,,225500
''';
    test('parses rows, ignoring the opening-forward line', () {
      final r = StatementParser.parse(csv);
      final s = r.statement;
      expect(s.bankName, 'HBL');
      expect(s.transactions.length, 3);
      expect(s.transactions[0].description, 'POS PURCHASE IMTIAZ SUPER MARKET, DHA');
      expect(s.transactions[0].amount, 4500);
      expect(s.transactions[0].isExpense, isTrue);
      expect(s.transactions[1].amount, 150000);
      expect(s.transactions[1].isExpense, isFalse);
      expect(s.transactions[2].amount, 20000);
      expect(r.dayFirst, isTrue);
      expect(s.periodStart, DateTime(2026, 10, 2));
      expect(s.periodEnd, DateTime(2026, 10, 13));
      expect(s.closingBalance, 225500);
      expect(s.openingBalance, 100000);
    });
    test('account number is masked to the last 4 digits', () {
      expect(StatementParser.parse(csv).statement.accountNumber, '••••0103');
    });
  });

  group('Meezan-style: single amount + type column, text months, newest first', () {
    const csv = '''Transaction Date,Description,Amount,Balance,Type
15-Oct-2026,Careem ride,850.00,48000.00,DR
12-Oct-2026,Raast transfer from Ali,10000.00,48850.00,CR
10-Oct-2026,K-Electric bill,"6,250.50",38850.00,DR
''';
    test('uses the type column and sorts oldest first', () {
      final s = StatementParser.parse(csv).statement;
      expect(s.transactions.map((t) => t.description).toList(),
          ['K-Electric bill', 'Raast transfer from Ali', 'Careem ride']);
      expect(s.transactions[0].amount, 6250.5);
      expect(s.transactions[0].isExpense, isTrue);
      expect(s.transactions[1].isExpense, isFalse);
      expect(s.totalDebits, 7100.5);
      expect(s.totalCredits, 10000);
      expect(s.closingBalance, 48000);
      expect(s.openingBalance, 45100.5);
    });
  });

  group('signed amounts, semicolons, ISO dates', () {
    const csv = '''Date;Details;Amount
2026-10-01;Coffee;-350,00
2026-10-02;Refund;1.200,50
2026-10-03;Rent;(45.000,00)
''';
    test('signs decide direction; european numbers parse', () {
      final s = StatementParser.parse(csv).statement;
      expect(s.transactions.length, 3);
      expect(s.transactions[0].isExpense, isTrue);
      expect(s.transactions[0].amount, 350);
      expect(s.transactions[1].isExpense, isFalse);
      expect(s.transactions[1].amount, 1200.5);
      expect(s.transactions[2].isExpense, isTrue);
      expect(s.transactions[2].amount, 45000);
    });
  });

  group('unsigned amounts: direction inferred from the running balance', () {
    const csv = '''Date,Narration,Amount,Running Balance
01/10/2026,Cash deposit,5000,15000
02/10/2026,Fuel,2000,13000
03/10/2026,Grocery,1500,11500
04/10/2026,Transfer in,3000,14500
''';
    test('balance deltas decide debit vs credit', () {
      final t = StatementParser.parse(csv).statement.transactions;
      expect(t.map((x) => x.isExpense).toList(), [false, true, true, false]);
    });
  });

  group('Dr/Cr suffix amounts', () {
    const csv = '''Date,Particulars,Amount
01/10/2026,Mobile top up,500.00 Dr
02/10/2026,Salary,60000.00 Cr
''';
    test('suffix decides direction', () {
      final t = StatementParser.parse(csv).statement.transactions;
      expect(t[0].isExpense, isTrue);
      expect(t[1].isExpense, isFalse);
      expect(t[1].amount, 60000);
    });
  });

  group('unknown layouts', () {
    const csv = '''When,What,How much,Extra
01/10/2026,Coffee,350,x
''';
    test('asks for a column mapping instead of guessing', () {
      expect(() => StatementParser.parse(csv), throwsA(isA<NeedsColumnMapping>()));
    });
    test('works once the user supplies a mapping', () {
      final s = StatementParser.parse(csv,
              mapping: const ColumnMapping(
                  headerRow: 0, date: 0, description: 1, amount: 2))
          .statement;
      expect(s.transactions.single.description, 'Coffee');
      expect(s.transactions.single.amount, 350);
    });
  });

  group('failure cases', () {
    test('empty file', () {
      expect(() => StatementParser.parse(''), throwsA(isA<StatementParseException>()));
    });
    test('header only', () {
      expect(() => StatementParser.parse('Date,Description,Debit,Credit,Balance\n'),
          throwsA(isA<StatementParseException>()));
    });
    test('rows without usable dates are skipped and counted', () {
      final r = StatementParser.parse(
          'Date,Description,Debit,Credit\n01/10/2026,A,5,\nTOTAL,,5,\n02/10/2026,B,7,\n');
      expect(r.statement.transactions.length, 2);
      expect(r.skippedRows, 1);
    });
  });

  group('bank detection', () {
    test('is word-based, so "ubl" inside another word does not match', () {
      expect(StatementParser.detectBank('Statement from Meezan Bank Ltd'), 'Meezan Bank');
      expect(StatementParser.detectBank('Trouble with doubled entries'), 'Bank statement');
    });
  });
}
