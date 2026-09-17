import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:outlay/features/subscription/data/subscription_service.dart';
import 'package:outlay/features/subscription/presentation/screens/paywall_screen.dart';

/// Reproduces the reported bug directly: pumps the real PaywallScreen with
/// realistic-but-long store product data (title, formatted price) at a
/// phone-width viewport, and asserts Flutter never recorded a layout
/// exception. Long/localized title and price strings are exactly what
/// App Store Connect / Google Play Console return in practice — this
/// screen's _PlanCard had never actually been exercised against anything
/// but short English placeholder-style strings before.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'CRITICAL: a plan card with a long product title, the "Best Value" '
      'badge, and a long non-USD-style price string does not overflow at '
      'a standard ~360dp phone width — reported as "subscription details '
      'distorted"', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final svc = SubscriptionService(prefs, debugProducts: [
      ProductDetails(
        id: SubscriptionService.kProAnnualId,
        title: 'Outlay Pro — Annual Subscription (Auto-Renewing)',
        description: 'Unlimited scans, annual billing',
        price: 'PKR 8,299.00 / year',
        rawPrice: 8299.0,
        currencyCode: 'PKR',
      ),
      ProductDetails(
        id: SubscriptionService.kProMonthlyId,
        title: 'Outlay Pro — Monthly Subscription (Auto-Renewing)',
        description: 'Unlimited scans, monthly billing',
        price: 'PKR 899.00 / month',
        rawPrice: 899.0,
        currencyCode: 'PKR',
      ),
    ]);
    addTearDown(svc.dispose);

    // Tall enough that both plan cards mount without needing to scroll —
    // this test is about width-overflow safety, not ListView scroll
    // behavior, and a plain ListView only mounts elements near its
    // viewport, so a merely-phone-height surface would make content
    // below the fold vanish from the tree, unrelated to the layout bug
    // actually being tested here.
    await tester.binding.setSurfaceSize(const Size(360, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: svc,
        child: const MaterialApp(home: PaywallScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'no RenderFlex overflow or other layout exception should '
            'be thrown while laying out a plan card with real-length '
            'store product data');
    // Both cards' content must actually be present (ellipsis truncates
    // visually, it doesn't remove the widget), proving the fix didn't
    // just hide the overflow by dropping content.
    expect(
        find.textContaining('Outlay Pro — Annual Subscription',
            findRichText: true),
        findsWidgets);
    expect(find.text('Best Value'), findsOneWidget);
    expect(find.textContaining('PKR 8,299.00', findRichText: true),
        findsWidgets);
    expect(find.textContaining('PKR 899.00', findRichText: true),
        findsWidgets);
  });
}
