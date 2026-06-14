import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String toDisplay(DateTime date) =>
      DateFormat('MMM d, yyyy').format(date);

  static String toShort(DateTime date) => DateFormat('MM/dd/yy').format(date);

  static String toMonthYear(DateTime date) =>
      DateFormat('MMMM yyyy').format(date);

  static String toIso(DateTime date) => date.toIso8601String();
}
