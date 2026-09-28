enum SubscriptionPlan { free, proMonthly, proAnnual, maxMonthly, maxAnnual }

class SubscriptionStatus {
  const SubscriptionStatus({
    required this.plan,
    required this.scansThisMonth,
    this.expiresAt,
    this.willAutoRenew,
    this.pendingPlan,
    this.familyGroupId,
    this.isFamilyAdmin = false,
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

  /// Family group ID if user is a MAX subscriber (null if not in a family)
  final String? familyGroupId;

  /// Whether user is the admin of their family group (MAX tier only)
  final bool isFamilyAdmin;

  bool get hasPendingPlanChange => pendingPlan != null && pendingPlan != plan;

  static const int freeScansPerMonth = 30;
  static const int proMaxAccounts = 3;

  bool get isPro => plan == SubscriptionPlan.proMonthly || plan == SubscriptionPlan.proAnnual;
  bool get isMax => plan == SubscriptionPlan.maxMonthly || plan == SubscriptionPlan.maxAnnual;
  bool get isPaid => isPro || isMax;

  bool get canScan => isPaid || scansThisMonth < freeScansPerMonth;
  int get scansRemaining =>
      isPaid ? -1 : (freeScansPerMonth - scansThisMonth).clamp(0, freeScansPerMonth);

  /// Account limit: 1 for free, 3 for pro, unlimited for max
  int get accountLimit => isMax ? 999 : (isPro ? proMaxAccounts : 1);

  bool get canCreateFamily => isMax;
  bool get inFamily => familyGroupId != null;
}
