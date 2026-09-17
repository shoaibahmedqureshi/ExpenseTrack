import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../settings/presentation/screens/privacy_policy_screen.dart';
import '../../../settings/presentation/screens/terms_of_service_screen.dart';
import '../../data/subscription_service.dart';
import '../../domain/subscription_status.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  static Future<void> show(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String? _selectedId;
  bool _buying = false;
  AppliedOffer? _appliedOffer;

  @override
  void initState() {
    super.initState();
    final svc = context.read<SubscriptionService>();
    _selectedId = svc.annualProduct?.id ?? svc.monthlyProduct?.id;
    // This is the one screen a user comes to check "what plan am I on" —
    // re-verify against StoreKit rather than trusting whatever was last
    // cached, since a plan change (or a switch that silently failed) can
    // otherwise go unreflected until something else happens to trigger a
    // refresh.
    svc.refreshEntitlement();
  }

  Future<void> _subscribe() async {
    if (_selectedId == null) return;
    final svc = context.read<SubscriptionService>();
    setState(() => _buying = true);
    try {
      final offer = _appliedOffer;
      if (offer != null && offer.product.id == _selectedId) {
        await svc.redeemOffer(offer);
      } else {
        final product = svc.products.firstWhere((p) => p.id == _selectedId);
        await svc.buy(product);
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _openRedeemDialog() async {
    final offer = await showDialog<AppliedOffer>(
      context: context,
      builder: (_) => const _RedeemCodeDialog(),
    );
    if (offer == null || !mounted) return;
    setState(() {
      _appliedOffer = offer;
      // The discount only applies to one specific product — select it so
      // the CTA and the discount badge agree on which plan is being bought.
      _selectedId = offer.product.id;
    });
  }

  void _clearCode() {
    setState(() => _appliedOffer = null);
  }

  // Handles a tap on any plan card. Behavior depends on subscription state,
  // not just which card was tapped: a free user is still picking a plan to
  // buy (two-step select-then-Continue below); a Pro user tapping their
  // *own* current plan sees its status/manage options, and tapping the
  // *other* plan switches to it directly in one tap — same single-tap-to-buy
  // pattern Stitchify uses for plan switching, since a Pro user changing
  // plans is a deliberate action the platform's own purchase confirmation
  // already gates, not something that needs an extra in-app "Continue" step.
  void _onPlanTap(dynamic product, bool isCurrentPlan) {
    if (_buying) return;
    final status = context.read<SubscriptionService>().status;
    if (status.isPro) {
      if (isCurrentPlan) {
        _showCurrentPlanDialog(context, product.title);
      } else {
        _switchPlan(product);
      }
    } else {
      setState(() => _selectedId = product.id);
    }
  }

  Future<void> _switchPlan(dynamic product) async {
    setState(() => _buying = true);
    try {
      await context.read<SubscriptionService>().buy(product);
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SubscriptionService>();
    final monthly = svc.monthlyProduct;
    final annual = svc.annualProduct;
    final status = svc.status;
    final isPro = status.isPro;
    final isMonthlyCurrent = isPro && status.plan == SubscriptionPlan.proMonthly;
    final isAnnualCurrent = isPro && status.plan == SubscriptionPlan.proAnnual;
    // Apple/Google both defer a downgrade/crossgrade (e.g. Annual→Monthly)
    // to the next renewal rather than applying it mid-cycle — so `plan`
    // above correctly keeps reporting Annual as current, and this is what
    // makes the pending switch visible instead of looking like the tap did
    // nothing (see SubscriptionStatus.pendingPlan).
    final hasPendingChange = status.hasPendingPlanChange;
    final isAnnualPendingTarget =
        hasPendingChange && status.pendingPlan == SubscriptionPlan.proAnnual;
    final isMonthlyPendingTarget =
        hasPendingChange && status.pendingPlan == SubscriptionPlan.proMonthly;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () async {
              await svc.restorePurchases();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Purchases restored')),
                );
              }
            },
            child: const Text('Restore',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: svc.loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  children: [
                    // Crown header
                    const _ProHeader(),
                    const SizedBox(height: 32),

                    // Feature list
                    ..._features.map((f) => _FeatureRow(
                          icon: f.$1,
                          title: f.$2,
                          subtitle: f.$3,
                        )),
                    const SizedBox(height: 32),

                    // Plan cards — always shown, even when already Pro, so
                    // switching plans is just tapping the other card (see
                    // _onPlanTap) instead of needing a separate screen.
                    if (annual != null)
                      _PlanCard(
                        product: annual,
                        badge: 'Best Value',
                        savings: _annualSavings(monthly, annual),
                        discountedPriceLabel: _appliedOffer?.product.id == annual.id
                            ? _appliedOffer?.discountedPriceLabel
                            : null,
                        selected: isPro ? isAnnualCurrent : _selectedId == annual.id,
                        isCurrentPlan: isAnnualCurrent,
                        isCancelled: isAnnualCurrent && status.willAutoRenew == false,
                        pendingLabel: isAnnualPendingTarget && status.expiresAt != null
                            ? 'Starts ${_formatDate(status.expiresAt!)}'
                            : null,
                        switchingAwayLabel: isAnnualCurrent &&
                                hasPendingChange &&
                                status.willAutoRenew != false
                            ? 'Switching to Monthly — tap to view details'
                            : null,
                        onTap: () => _onPlanTap(annual, isAnnualCurrent),
                      ),
                    if (annual != null) const SizedBox(height: 12),
                    if (monthly != null)
                      _PlanCard(
                        product: monthly,
                        discountedPriceLabel: _appliedOffer?.product.id == monthly.id
                            ? _appliedOffer?.discountedPriceLabel
                            : null,
                        selected: isPro ? isMonthlyCurrent : _selectedId == monthly.id,
                        isCurrentPlan: isMonthlyCurrent,
                        isCancelled: isMonthlyCurrent && status.willAutoRenew == false,
                        pendingLabel: isMonthlyPendingTarget && status.expiresAt != null
                            ? 'Starts ${_formatDate(status.expiresAt!)}'
                            : null,
                        switchingAwayLabel: isMonthlyCurrent &&
                                hasPendingChange &&
                                status.willAutoRenew != false
                            ? 'Switching to Annual — tap to view details'
                            : null,
                        onTap: () => _onPlanTap(monthly, isMonthlyCurrent),
                      ),

                    if (svc.products.isEmpty) ...[
                      const _StorePlaceholder(),
                      if (isPro) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => _showCurrentPlanDialog(
                                context,
                                isAnnualCurrent
                                    ? 'Annual Plan'
                                    : 'Monthly Plan'),
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24)),
                            child: const Text('Manage Subscription',
                                style: TextStyle(color: Colors.white70)),
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 16),
                    Center(
                      child: _appliedOffer != null
                          ? GestureDetector(
                              onTap: _clearCode,
                              child: Text(
                                  '"${_appliedOffer!.code}" applied — tap to remove',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            )
                          : TextButton(
                              onPressed: _openRedeemDialog,
                              child: const Text('Redeem Code',
                                  style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ),
                    ),

                    // Previously a failed purchase/plan-switch (declined,
                    // already subscribed via a different channel, a
                    // subscription-group conflict in App Store Connect,
                    // etc.) surfaced nowhere — the screen just silently
                    // didn't update, indistinguishable from a UI refresh
                    // bug. See SubscriptionService.buy().
                    if (svc.error != null) ...[
                      const SizedBox(height: 16),
                      Text(svc.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13)),
                    ],

                    const SizedBox(height: 28),

                    // CTA — only for a free user still picking a plan; a
                    // Pro user acts directly via the cards above (see
                    // _onPlanTap), same as Stitchify's single-tap-to-buy
                    // pattern once already subscribed.
                    if (!isPro) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_buying || svc.products.isEmpty)
                              ? null
                              : _subscribe,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _buying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Text('Continue',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Subscriptions auto-renew unless cancelled 24 hours before the end '
                      'of the current period. Manage in your account settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    // Required by App Store Review Guideline 3.1.2: a
                    // functional link to the Privacy Policy and Terms of
                    // Service/EULA must appear on the subscription purchase
                    // screen itself, not just somewhere else in the app.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PrivacyPolicyScreen())),
                          child: const Text('Privacy Policy',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  decoration: TextDecoration.underline)),
                        ),
                        const Text('   •   ',
                            style: TextStyle(color: Colors.white24, fontSize: 11)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const TermsOfServiceScreen())),
                          child: const Text('Terms of Service',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }

  String? _annualSavings(dynamic monthly, dynamic annual) {
    if (monthly == null) return null;
    try {
      final monthlyRaw = monthly.rawPrice as double;
      final annualRaw = annual.rawPrice as double;
      final saving = ((monthlyRaw * 12 - annualRaw) / (monthlyRaw * 12) * 100)
          .round();
      return saving > 0 ? 'Save $saving%' : null;
    } catch (_) {
      return 'Save 33%';
    }
  }
}

// ─── Features ─────────────────────────────────────────────────────────────────

const _features = [
  (Icons.document_scanner_outlined, 'Unlimited Receipt Scans',
      'No monthly cap — scan every receipt you get'),
  (Icons.bar_chart_rounded, 'Advanced Reports',
      'Monthly breakdowns, category trends & exports'),
  (Icons.cloud_sync_outlined, 'Priority Sync',
      'Background sync across all your devices'),
  (Icons.lock_outline, 'Secure & Private',
      'Your data is encrypted end-to-end'),
];

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _ProHeader extends StatelessWidget {
  const _ProHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.workspace_premium,
              color: Colors.white, size: 40),
        ),
        const SizedBox(height: 20),
        const Text('Upgrade to Pro',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Unlock the full expense tracking experience',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14)),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Color(0xFF4CD964), size: 20),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.product,
    required this.selected,
    required this.onTap,
    this.badge,
    this.savings,
    this.discountedPriceLabel,
    this.isCurrentPlan = false,
    this.isCancelled = false,
    this.pendingLabel,
    this.switchingAwayLabel,
  });

  final dynamic product;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;
  final String? savings;

  /// Set when an applied influencer code's offer matches this specific
  /// product — the store's own live discounted price (see AppliedOffer),
  /// never something this widget computes itself.
  final String? discountedPriceLabel;

  /// True if this card is the plan the user is actually subscribed to right
  /// now (not just the one selected in the free-tier picker) — swaps the
  /// badge to CURRENT PLAN/CANCELLED and the price column to a status icon,
  /// mirroring Stitchify's already-subscribed plan card.
  final bool isCurrentPlan;
  final bool isCancelled;

  /// Set when this card is the *other* plan that a pending downgrade/
  /// crossgrade will switch to at the next renewal (e.g. "Starts Dec 1") —
  /// shown as its own badge since this card isn't current yet, just queued.
  final String? pendingLabel;

  /// Set on the *current* plan's card when a pending switch away from it
  /// exists (e.g. "Switching to Monthly — tap to view details") — pairs
  /// with the other card's [pendingLabel] so both halves of the change are
  /// visible, not just one side of it.
  final String? switchingAwayLabel;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF4CD964);
    const cancelledColor = Color(0xFFFF9800);
    const pendingColor = Color(0xFF64B5F6);
    final stateColor = isCancelled ? cancelledColor : activeColor;
    final effectiveBadge = isCurrentPlan
        ? (isCancelled ? 'CANCELLED' : 'CURRENT PLAN')
        : pendingLabel != null
            ? 'UPCOMING'
            : badge;
    final badgeColor = isCurrentPlan
        ? stateColor
        : pendingLabel != null
            ? pendingColor
            : const Color(0xFFFFD700);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : const Color(0xFF1A1A2E),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : const Color(0xFF2A2A3E),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected
                        ? AppTheme.primaryColor
                        : Colors.white38,
                    width: 2),
                color: selected ? AppTheme.primaryColor : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wrap rather than Row: the real title string comes
                  // from App Store Connect/Play Console, isn't under this
                  // app's control, and can't be reliably squeezed into
                  // whatever sliver of width is left after the fixed-size
                  // "Best Value" badge next to it — a Row (even with the
                  // title in Flexible+ellipsis) can still overflow by a
                  // few pixels once the remaining space gets narrow
                  // enough that ellipsis has nothing left to truncate
                  // into (exactly the "subscription details distorted"
                  // report; real store titles/badges never got exercised
                  // against this row in dev). Wrap can't overflow its
                  // parent's width by construction — it drops the badge
                  // to its own line instead once the title needs the
                  // space, at the cost of a slightly taller card.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(product.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      if (effectiveBadge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(effectiveBadge,
                              style: TextStyle(
                                  color: isCurrentPlan || pendingLabel != null
                                      ? Colors.white
                                      : Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                  if (pendingLabel != null)
                    Text(pendingLabel!,
                        style: const TextStyle(
                            color: pendingColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600))
                  else if (savings != null && !isCurrentPlan)
                    Text(savings!,
                        style: const TextStyle(
                            color: Color(0xFF4CD964),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  if (isCurrentPlan && isCancelled)
                    const Text('Won\'t renew — tap to view details',
                        style: TextStyle(
                            color: cancelledColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600))
                  else if (isCurrentPlan && switchingAwayLabel != null)
                    Text(switchingAwayLabel!,
                        style: const TextStyle(
                            color: pendingColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isCurrentPlan)
              Icon(isCancelled ? Icons.error_outline : Icons.check_circle,
                  color: stateColor, size: 22)
            else
              // Same reasoning as the title above: store-formatted price
              // strings vary a lot by locale/currency (e.g. non-USD
              // currencies routinely produce longer strings than "$4.99"),
              // so this can't be a bare unconstrained Text either.
              Flexible(
                child: discountedPriceLabel != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(product.price,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough)),
                          Text(discountedPriceLabel!,
                              // Unlike the plain store price above, this can
                              // be a full sentence (e.g. "$14.99 for your
                              // first year" — server-supplied text for iOS
                              // native offer codes, see AppliedOffer), not
                              // just a short formatted price, so it needs
                              // room to wrap rather than a single-line
                              // ellipsis that silently swallows most of it.
                              maxLines: 2,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: Color(0xFF4CD964),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                        ],
                      )
                    : Text(product.price,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }
}

/// The "Redeem Code" modal — a code field, an Apply Code button, and a
/// Cancel link, matching the standalone dialog design (as opposed to an
/// inline expanding field) so entering a code doesn't rearrange the
/// paywall underneath it. Owns its own loading/error state locally and
/// pops with the resolved [AppliedOffer] on success, or null on Cancel.
class _RedeemCodeDialog extends StatefulWidget {
  const _RedeemCodeDialog();

  @override
  State<_RedeemCodeDialog> createState() => _RedeemCodeDialogState();
}

class _RedeemCodeDialogState extends State<_RedeemCodeDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final offer = await context.read<SubscriptionService>().lookupOfferCode(code);
    if (!mounted) return;
    if (offer != null) {
      Navigator.pop(context, offer);
    } else {
      setState(() {
        _loading = false;
        _error = 'Invalid or expired code';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Redeem Code',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text(
                'Enter your promo code below to unlock your special offer.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.4)),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              autofocus: true,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, letterSpacing: 2),
              decoration: InputDecoration(
                hintText: 'ABCD-1234',
                hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 2),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF3A3A4E)),
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onSubmitted: (_) => _apply(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Apply Code',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorePlaceholder extends StatelessWidget {
  const _StorePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: const Column(
        children: [
          Icon(Icons.store_outlined, color: Colors.white38, size: 32),
          SizedBox(height: 8),
          Text('Products not available in this environment',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          SizedBox(height: 4),
          Text(
              'Set up products in App Store Connect / Google Play Console\n'
              'to enable purchases.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// Shown when tapping the plan card the user is already subscribed to —
/// surfaces renewal/cancellation status and hands off to the platform's
/// native manage-subscriptions sheet, mirroring Stitchify's current-plan
/// dialog. Switching to a *different* plan doesn't go through this at all;
/// see _onPlanTap in _PaywallScreenState.
Future<void> _showCurrentPlanDialog(BuildContext context, String title) async {
  final svc = context.read<SubscriptionService>();
  final status = svc.status;
  final isCancelled = status.willAutoRenew == false;
  final expiresAt = status.expiresAt;
  // Apple/Google defer a downgrade/crossgrade to the next renewal rather
  // than applying it immediately or refunding the current period — so this
  // dialog can be showing the still-active plan while a switch away from it
  // is already queued (see SubscriptionStatus.pendingPlan).
  final pendingPlanName = status.hasPendingPlanChange
      ? (status.pendingPlan == SubscriptionPlan.proAnnual ? 'Annual' : 'Monthly')
      : null;

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: Text(isCancelled ? 'Subscription Cancelled' : 'Current Plan',
          style: const TextStyle(color: Colors.white)),
      content: Text(
        isCancelled
            ? 'Your "$title" subscription has been cancelled and won\'t renew.'
                '${expiresAt != null ? ' You\'ll keep access until ${_formatDate(expiresAt)}.' : ' You\'ll keep access until the current period ends.'}'
            : pendingPlanName != null
                ? 'You\'re currently subscribed to "$title".'
                    '${expiresAt != null ? ' Your plan will switch to $pendingPlanName on ${_formatDate(expiresAt)} — no charge until then, and nothing from your current period is refunded.' : ' Your plan will switch to $pendingPlanName at your next renewal.'}'
                : 'You\'re currently subscribed to "$title".'
                    '${expiresAt != null ? ' Renews ${_formatDate(expiresAt)}.' : ''}',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final opened = await svc.openManageSubscriptions();
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Could not open subscription management')),
              );
            }
          },
          child: const Text('Manage Subscription',
              style: TextStyle(
                  color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
