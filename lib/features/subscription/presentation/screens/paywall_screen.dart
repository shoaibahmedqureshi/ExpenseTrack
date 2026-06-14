import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    final svc = context.read<SubscriptionService>();
    _selectedId = svc.annualProduct?.id ?? svc.monthlyProduct?.id;
  }

  Future<void> _subscribe() async {
    if (_selectedId == null) return;
    final svc = context.read<SubscriptionService>();
    final product = svc.products.firstWhere((p) => p.id == _selectedId);
    setState(() => _buying = true);
    try {
      await svc.buy(product);
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SubscriptionService>();
    final monthly = svc.monthlyProduct;
    final annual = svc.annualProduct;
    final isPro = svc.status.isPro;

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
          : isPro
              ? _AlreadyPro(plan: svc.status.plan)
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

                    // Plan cards
                    if (annual != null)
                      _PlanCard(
                        product: annual,
                        badge: 'Best Value',
                        savings: _annualSavings(monthly, annual),
                        selected: _selectedId == annual.id,
                        onTap: () => setState(() => _selectedId = annual.id),
                      ),
                    if (annual != null) const SizedBox(height: 12),
                    if (monthly != null)
                      _PlanCard(
                        product: monthly,
                        selected: _selectedId == monthly.id,
                        onTap: () => setState(() => _selectedId = monthly.id),
                      ),

                    if (svc.products.isEmpty)
                      const _StorePlaceholder(),

                    const SizedBox(height: 28),

                    // CTA
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
                    const Text(
                      'Subscriptions auto-renew unless cancelled 24 hours before the end '
                      'of the current period. Manage in your account settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 11),
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
  });

  final dynamic product;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;
  final String? savings;

  @override
  Widget build(BuildContext context) {
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
                  Row(
                    children: [
                      Text(product.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(badge!,
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                  if (savings != null)
                    Text(savings!,
                        style: const TextStyle(
                            color: Color(0xFF4CD964),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Text(product.price,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
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

class _AlreadyPro extends StatelessWidget {
  const _AlreadyPro({required this.plan});
  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.workspace_premium,
                color: Color(0xFFFFD700), size: 72),
            const SizedBox(height: 20),
            const Text("You're Pro!",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              plan == SubscriptionPlan.proAnnual
                  ? 'Annual subscription active'
                  : 'Monthly subscription active',
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24)),
              child: const Text('Back',
                  style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
