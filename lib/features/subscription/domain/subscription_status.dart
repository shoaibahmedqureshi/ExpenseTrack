enum SubscriptionPlan { free, proMonthly, proAnnual }

class SubscriptionStatus {
  const SubscriptionStatus({
    required this.plan,
    required this.scansThisMonth,
    this.expiresAt,
    this.willAutoRenew,
    this.pendingPlan,
  });

  final SubscriptionPlan plan;
  final int scansThisMonth;
  final DateTime? expiresAt;

  /// Whether the active subscription is set to renew, or null if not a
  /// subscription (free) or not yet known (native status hasn't resolved).
  final bool? willAutoRenew;

  /// The plan that will actually take effect at the *next* renewal, if it
  /// differs from [plan] — i.e. a downgrade/crossgrade (e.g. Annual to
  /// Monthly) is pending. Apple and Google both defer these to the next
  /// renewal rather than applying them mid-cycle or refunding what's
  /// already been paid, so [plan] keeps reporting the currently-active
  /// plan correctly until then — this field is what makes that pending
  /// change visible instead of silent.
  final SubscriptionPlan? pendingPlan;

  bool get hasPendingPlanChange => pendingPlan != null && pendingPlan != plan;

  static const int freeScansPerMonth = 30;

  bool get isPro => plan != SubscriptionPlan.free;
  bool get canScan => isPro || scansThisMonth < freeScansPerMonth;
  int get scansRemaining =>
      isPro ? -1 : (freeScansPerMonth - scansThisMonth).clamp(0, freeScansPerMonth);
}
