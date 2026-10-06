import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/expense_split/domain/split_calculator.dart';

void main() {
  group('toCents', () {
    test('parses valid amounts', () {
      expect(SplitCalculator.toCents('12'), 1200);
      expect(SplitCalculator.toCents('12.5'), 1250);
      expect(SplitCalculator.toCents('12.34'), 1234);
      expect(SplitCalculator.toCents('1,234.56'), 123456);
      expect(SplitCalculator.toCents(' 0.07 '), 7);
    });
    test('rejects invalid', () {
      for (final bad in ['', 'abc', '-5', '1.234', '1..2', '.5', '5.']) {
        expect(SplitCalculator.toCents(bad), isNull, reason: bad);
      }
    });
  });

  group('equalShares', () {
    test('divides evenly', () {
      expect(SplitCalculator.equalShares(900, ['a', 'b', 'c']),
          {'a': 300, 'b': 300, 'c': 300});
    });
    test('leftover cents go to the first members and total is exact', () {
      final s = SplitCalculator.equalShares(1000, ['a', 'b', 'c']);
      expect(s, {'a': 334, 'b': 333, 'c': 333});
      expect(s.values.reduce((a, b) => a + b), 1000);
    });
    test('1 cent among 3 people', () {
      expect(SplitCalculator.equalShares(1, ['a', 'b', 'c']),
          {'a': 1, 'b': 0, 'c': 0});
    });
    test('empty list', () {
      expect(SplitCalculator.equalShares(500, []), isEmpty);
    });
  });

  group('percentShares', () {
    test('simple halves', () {
      expect(SplitCalculator.percentShares(1000, {'a': 50, 'b': 50}),
          {'a': 500, 'b': 500});
    });
    test('thirds sum exactly via largest remainder', () {
      final s = SplitCalculator.percentShares(
          1000, {'a': 33.34, 'b': 33.33, 'c': 33.33})!;
      expect(s.values.reduce((a, b) => a + b), 1000);
      expect(s['a'], 334);
    });
    test('awkward total always sums exactly', () {
      final s = SplitCalculator.percentShares(
          9999, {'a': 12.5, 'b': 37.5, 'c': 25, 'd': 25})!;
      expect(s.values.reduce((a, b) => a + b), 9999);
    });
    test('rejects when percentages do not total 100', () {
      expect(SplitCalculator.percentShares(1000, {'a': 60, 'b': 30}), isNull);
      expect(SplitCalculator.percentShares(1000, {'a': 70, 'b': 40}), isNull);
      expect(SplitCalculator.percentShares(1000, {'a': 120, 'b': -20}), isNull);
    });
  });

  group('validateAmountShares', () {
    test('valid', () {
      expect(SplitCalculator.validateAmountShares(1000, {'a': 400, 'b': 600}),
          isNull);
    });
    test('short / over', () {
      expect(SplitCalculator.validateAmountShares(1000, {'a': 400, 'b': 500}),
          contains('1.00 short'));
      expect(SplitCalculator.validateAmountShares(1000, {'a': 600, 'b': 600}),
          contains('2.00 over'));
    });
    test('zero total or no participants', () {
      expect(SplitCalculator.validateAmountShares(0, {'a': 0}), isNotNull);
      expect(SplitCalculator.validateAmountShares(500, {}), isNotNull);
      expect(
          SplitCalculator.validateAmountShares(500, {'a': 0, 'b': 0}), isNotNull);
    });
  });

  group('netBalances / simplifyDebts', () {
    test('payer is owed what others owe; own share is ignored', () {
      final net = SplitCalculator.netBalances([
        (paidBy: 'a', shares: {'a': 300, 'b': 300, 'c': 300}),
      ], []);
      expect(net, {'a': 600, 'b': -300, 'c': -300});
    });
    test('payments reduce balances and settle to zero', () {
      final net = SplitCalculator.netBalances([
        (paidBy: 'a', shares: {'a': 500, 'b': 500}),
      ], [
        (from: 'b', to: 'a', cents: 500),
      ]);
      expect(net, isEmpty);
    });
    test('partial payment leaves the remainder', () {
      final net = SplitCalculator.netBalances([
        (paidBy: 'a', shares: {'a': 500, 'b': 500}),
      ], [
        (from: 'b', to: 'a', cents: 200),
      ]);
      expect(net, {'a': 300, 'b': -300});
    });
    test('simplify reduces transfers', () {
      // a paid 900 for a,b,c ; b paid 300 for b,c
      final net = SplitCalculator.netBalances([
        (paidBy: 'a', shares: {'a': 300, 'b': 300, 'c': 300}),
        (paidBy: 'b', shares: {'b': 150, 'c': 150}),
      ], []);
      final debts = SplitCalculator.simplifyDebts(net);
      // c owes 450 total: 300 to a, 150 to b ; b owes a 300 but is owed 150 => net b -150
      expect(debts.fold<int>(0, (s, d) => s + d.cents),
          net.values.where((v) => v > 0).fold<int>(0, (a, b) => a + b));
      // everyone nets out when debts are applied
      final after = Map<String, int>.from(net);
      for (final d in debts) {
        after[d.from] = after[d.from]! + d.cents;
        after[d.to] = after[d.to]! - d.cents;
      }
      expect(after.values.every((v) => v == 0), isTrue);
      expect(debts.length, lessThanOrEqualTo(2));
    });
    test('nobody owes anything', () {
      expect(SplitCalculator.simplifyDebts({}), isEmpty);
    });
  });

  group('myTotals', () {
    test('sums what I owe and what I am owed separately', () {
      final debts = [
        const Debt('me', 'a', 700),
        const Debt('b', 'me', 1250),
        const Debt('c', 'me', 50),
        const Debt('b', 'a', 999),
      ];
      final t = SplitCalculator.myTotals(debts, 'me');
      expect(t.owe, 700);
      expect(t.owed, 1300);
    });
    test('nothing involving me', () {
      final t = SplitCalculator.myTotals([const Debt('a', 'b', 5)], 'me');
      expect(t.owe, 0);
      expect(t.owed, 0);
    });
  });
}
