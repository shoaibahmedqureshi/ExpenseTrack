/// The periods the revenue dashboard can show, as calendar periods in the user's own time zone.
enum RevenuePeriod { allTime, thisYear, thisMonth }

/// Start of [period], or null for all time. "This year" begins on 1 January and "this month"
/// on the 1st, at local midnight, so a purchase at 00:30 on the 1st counts in the new period.
DateTime? revenuePeriodStart(RevenuePeriod period, DateTime now) {
  switch (period) {
    case RevenuePeriod.allTime:
      return null;
    case RevenuePeriod.thisYear:
      return DateTime(now.year, 1, 1);
    case RevenuePeriod.thisMonth:
      return DateTime(now.year, now.month, 1);
  }
}
