enum SubscriptionPlan { free, proMonthly, proAnnual }

class SubscriptionStatus {
  const SubscriptionStatus({
    required this.plan,
    required this.scansThisMonth,
    this.expiresAt,
  });

  final SubscriptionPlan plan;
  final int scansThisMonth;
  final DateTime? expiresAt;

  static const int freeScansPerMonth = 30;

  bool get isPro => plan != SubscriptionPlan.free;
  bool get canScan => isPro || scansThisMonth < freeScansPerMonth;
  int get scansRemaining =>
      isPro ? -1 : (freeScansPerMonth - scansThisMonth).clamp(0, freeScansPerMonth);
}
