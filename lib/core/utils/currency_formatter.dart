import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _formatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 2,
  );

  static String format(double amount) => _formatter.format(amount);

  static String formatCompact(double amount) =>
      NumberFormat.compactCurrency(symbol: '\$').format(amount);
}
