import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/categories/domain/entities/category.dart';
import 'package:outlay/features/expenses/domain/entities/expense.dart';
import 'package:outlay/features/import/data/services/duplicate_detector.dart';
import 'package:outlay/features/import/domain/entities/bank_statement.dart';

Category get _cat => Category(id: 1, name: 'Food', icon: Icons.restaurant, color: Colors.red);

Expense _e(String title, double amount, DateTime date, {bool income = false}) => Expense(
      id: 1,
      title: title,
      amount: amount,
      date: date,
      type: income ? TransactionType.income : TransactionType.expense,
      category: _cat,
    );

BankStatementTransaction _t(String d, double amount, DateTime date, {String type = 'debit'}) =>
    BankStatementTransaction(date: date, description: d, amount: amount, type: type);

void main() {
  final day = DateTime(2026, 10, 5);

  test('same day and amount is a duplicate', () {
    final r = DuplicateDetector.findDuplicates(_t('IMTIAZ SUPERMARKET', 4500, day), [_e('Imtiaz', 4500, day)]);
    expect(r, isNotEmpty);
    expect(r.first.isDuplicate, isTrue);
  });

  test('same day but DIFFERENT amount is not a duplicate', () {
    final r = DuplicateDetector.findDuplicates(_t('Fuel', 5000, day), [_e('Lunch', 450, day)]);
    expect(r.where((m) => m.isDuplicate), isEmpty);
  });

  test('same amount weeks apart is not a duplicate', () {
    final r = DuplicateDetector.findDuplicates(_t('Rent', 45000, day), [_e('Rent', 45000, day.subtract(const Duration(days: 30)))]);
    expect(r.where((m) => m.isDuplicate), isEmpty);
  });

  test('same amount a day apart is flagged at least as possible', () {
    final r = DuplicateDetector.findDuplicates(_t('Careem', 850, day), [_e('Ride', 850, day.add(const Duration(days: 1)))]);
    expect(r, isNotEmpty);
  });
}
