import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/import/data/services/statement_categorizer.dart';

void main() {
  const defaults = ['Food', 'Transport', 'Shopping', 'Health', 'Entertainment', 'Salary', 'Other'];
  String? s(String d, {bool expense = true, List<String> have = defaults}) =>
      StatementCategorizer.suggest(d, isExpense: expense, available: have);

  test('common Pakistani merchants map to default categories', () {
    expect(s('POS PURCHASE IMTIAZ SUPER MARKET DHA'), 'Food');
    expect(s('CAREEM RIDE KARACHI'), 'Transport');
    expect(s('PSO FUEL STATION'), 'Transport');
    expect(s('DARAZ.PK ORDER 12345'), 'Shopping');
    expect(s('NETFLIX.COM'), 'Entertainment');
    expect(s('CHUGHTAI LAB'), 'Health');
  });
  test('salary is only suggested for credits', () {
    expect(s('SALARY OCT 2026', expense: false), 'Salary');
    expect(s('SALARY OCT 2026', expense: true), isNull);
    expect(s('Raast transfer from Ali', expense: false), isNull);
  });
  test('only suggests categories the user has (case-insensitive)', () {
    expect(s('K-Electric bill'), isNull); // no Bills category by default
    expect(s('K-Electric bill', have: [...defaults, 'bills']), 'bills');
    expect(s('KFC', have: ['Transport']), isNull);
  });
  test('unknown text gives no suggestion', () {
    expect(s('IBFT TRANSFER 000123'), isNull);
  });
}
