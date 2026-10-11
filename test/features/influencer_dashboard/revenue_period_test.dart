import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/influencer_dashboard/domain/revenue_period.dart';

void main() {
  final now = DateTime(2026, 10, 12, 15, 30);

  test('all time has no start', () {
    expect(revenuePeriodStart(RevenuePeriod.allTime, now), isNull);
  });

  test('this year starts on 1 January at local midnight', () {
    expect(
        revenuePeriodStart(RevenuePeriod.thisYear, now), DateTime(2026, 1, 1));
  });

  test('this month starts on the 1st at local midnight', () {
    expect(revenuePeriodStart(RevenuePeriod.thisMonth, now),
        DateTime(2026, 10, 1));
  });

  test('it is calendar based, not a rolling window', () {
    // 30 days before 12 Oct is 12 Sep, but this month starts on 1 Oct.
    final rolling = now.subtract(const Duration(days: 30));
    expect(revenuePeriodStart(RevenuePeriod.thisMonth, now)!.isAfter(rolling),
        isTrue);
    // 365 days before 12 Oct 2026 is 12 Oct 2025, but this year starts on 1 Jan 2026.
    final rollingYear = now.subtract(const Duration(days: 365));
    expect(
        revenuePeriodStart(RevenuePeriod.thisYear, now)!.isAfter(rollingYear),
        isTrue);
  });

  test('the first minute of a month belongs to the new month', () {
    final first = DateTime(2026, 11, 1, 0, 5);
    expect(revenuePeriodStart(RevenuePeriod.thisMonth, first),
        DateTime(2026, 11, 1));
  });

  test('January edge: this year and this month start the same day', () {
    final jan = DateTime(2027, 1, 20);
    expect(
        revenuePeriodStart(RevenuePeriod.thisYear, jan), DateTime(2027, 1, 1));
    expect(
        revenuePeriodStart(RevenuePeriod.thisMonth, jan), DateTime(2027, 1, 1));
  });
}
