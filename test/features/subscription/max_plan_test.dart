import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:outlay/features/subscription/data/subscription_service.dart';
import 'package:outlay/features/subscription/domain/subscription_status.dart';
import 'package:outlay/features/subscription/presentation/screens/paywall_screen.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the store so a tap on Continue can be seen reaching "buy" with the right product.
class _FakeStore extends InAppPurchasePlatform with MockPlatformInterfaceMixin {
  final bought = <String>[];

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    bought.add(purchaseParam.productDetails.id);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

ProductDetails _p(String id, String title, double price, String label) =>
    ProductDetails(id: id, title: title, description: title, price: label, rawPrice: price, currencyCode: 'USD');

final _pro = [
  _p(SubscriptionService.kProAnnualId, 'Outlay Pro Annual', 19.99, '\$19.99'),
  _p(SubscriptionService.kProMonthlyId, 'Outlay Pro Monthly', 2.99, '\$2.99'),
];
final _max = [
  _p(SubscriptionService.kMaxAnnualId, 'Outlay MAX Annual', 39.99, '\$39.99'),
  _p(SubscriptionService.kMaxMonthlyId, 'Outlay MAX Monthly', 4.99, '\$4.99'),
];

PurchaseDetails _purchase(String id, {PurchaseStatus status = PurchaseStatus.purchased}) => PurchaseDetails(
      productID: id,
      verificationData: PurchaseVerificationData(localVerificationData: '', serverVerificationData: '', source: 'test'),
      transactionDate: null,
      status: status,
    );

Future<SubscriptionService> _service({String? plan, List<ProductDetails>? products}) async {
  SharedPreferences.setMockInitialValues({if (plan != null) 'sub_plan': plan});
  final prefs = await SharedPreferences.getInstance();
  return SubscriptionService(prefs, debugProducts: products ?? [..._pro, ..._max]);
}

Future<void> _openPaywall(WidgetTester t, SubscriptionService svc, {PaywallTier? tier}) async {
  await t.binding.setSurfaceSize(const Size(390, 1800));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(ChangeNotifierProvider.value(
    value: svc,
    child: MaterialApp(home: PaywallScreen(initialTier: tier)),
  ));
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeStore store;

  // The purchase plugin registers the Android billing client the first time it is touched on an "android"
  // target, which tries to open a real connection. Any other platform leaves it alone, so the fake store below is
  // the only thing that ever receives a purchase.
  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    InAppPurchase.instance; // created once here; later accesses reuse it
    debugDefaultTargetPlatformOverride = null;
  });

  setUp(() {
    store = _FakeStore();
    InAppPurchasePlatform.instance = store;
  });

  group('plans and purchases', () {
    test('every product maps to its own plan; unknown products to none', () {
      expect(SubscriptionService.planFromProductId(SubscriptionService.kProMonthlyId), SubscriptionPlan.proMonthly);
      expect(SubscriptionService.planFromProductId(SubscriptionService.kProAnnualId), SubscriptionPlan.proAnnual);
      expect(SubscriptionService.planFromProductId(SubscriptionService.kMaxMonthlyId), SubscriptionPlan.maxMonthly);
      expect(SubscriptionService.planFromProductId(SubscriptionService.kMaxAnnualId), SubscriptionPlan.maxAnnual);
      expect(SubscriptionService.planFromProductId('something_else'), isNull);
      expect(SubscriptionService.planFromProductId(null), isNull);
    });

    test('the entitlement check asks the store about MAX as well as Pro', () {
      // Otherwise a MAX subscriber looks like "nothing active" and is downgraded to free.
      expect(SubscriptionService.entitlementProductIds, containsAll([
        SubscriptionService.kProMonthlyId, SubscriptionService.kProAnnualId,
        SubscriptionService.kMaxMonthlyId, SubscriptionService.kMaxAnnualId,
      ]));
    });

    test('buying MAX records MAX, not Pro', () async {
      final svc = await _service();
      await svc.handlePurchaseForTest(_purchase(SubscriptionService.kMaxMonthlyId));
      expect(svc.status.plan, SubscriptionPlan.maxMonthly);
      expect(svc.status.isMax, isTrue);
      expect(svc.status.isPaid, isTrue);
      await svc.handlePurchaseForTest(_purchase(SubscriptionService.kMaxAnnualId));
      expect(svc.status.plan, SubscriptionPlan.maxAnnual);
    });

    test('restoring a MAX purchase also records MAX', () async {
      final svc = await _service();
      await svc.handlePurchaseForTest(_purchase(SubscriptionService.kMaxAnnualId, status: PurchaseStatus.restored));
      expect(svc.status.isMax, isTrue);
    });

    test('buying Pro still records Pro, and is not MAX', () async {
      final svc = await _service();
      await svc.handlePurchaseForTest(_purchase(SubscriptionService.kProAnnualId));
      expect(svc.status.plan, SubscriptionPlan.proAnnual);
      expect(svc.status.isMax, isFalse);
      expect(svc.status.canCreateFamily, isFalse);
    });

    test('a product we do not sell leaves the plan alone', () async {
      final svc = await _service(plan: 'proMonthly');
      await svc.handlePurchaseForTest(_purchase('something_else'));
      expect(svc.status.plan, SubscriptionPlan.proMonthly);
    });

    test('a failed purchase reports the error and changes nothing', () async {
      final svc = await _service();
      final p = _purchase(SubscriptionService.kMaxMonthlyId, status: PurchaseStatus.error)
        ..error = IAPError(source: 'test', code: 'x', message: 'Declined');
      await svc.handlePurchaseForTest(p);
      expect(svc.error, 'Declined');
      expect(svc.status.plan, SubscriptionPlan.free);
    });

    test('a MAX subscriber has unlimited scans, like Pro', () async {
      final svc = await _service(plan: 'maxMonthly');
      expect(await svc.tryIncrementScan(), isTrue);
    });
  });

  group('paywall', () {
    testWidgets('opens on Pro for a free user, with a Pro | MAX switch', (t) async {
      await _openPaywall(t, await _service());
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(find.text('MAX'), findsOneWidget);
      expect(find.text('Outlay Pro Annual'), findsOneWidget);
      expect(find.text('Outlay MAX Annual'), findsNothing);
    });

    testWidgets('asked for MAX (from the Family tab) it opens on the MAX plans', (t) async {
      await _openPaywall(t, await _service(), tier: PaywallTier.max);
      expect(find.text('Upgrade to MAX'), findsOneWidget);
      expect(find.text('Family sharing'), findsOneWidget);
      expect(find.text('Outlay MAX Annual'), findsOneWidget);
      expect(find.text('Outlay MAX Monthly'), findsOneWidget);
      expect(find.text('Outlay Pro Annual'), findsNothing);
    });

    testWidgets('switching tabs swaps the plans', (t) async {
      await _openPaywall(t, await _service());
      await t.tap(find.text('MAX'));
      await t.pumpAndSettle();
      expect(find.text('Upgrade to MAX'), findsOneWidget);
      expect(find.text('Outlay MAX Annual'), findsOneWidget);
      await t.tap(find.text('Pro'));
      await t.pumpAndSettle();
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(find.text('Outlay Pro Annual'), findsOneWidget);
    });

    testWidgets('Continue on MAX buys the MAX annual product by default', (t) async {
      await _openPaywall(t, await _service(), tier: PaywallTier.max);
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(store.bought, [SubscriptionService.kMaxAnnualId]);
    });

    testWidgets('picking MAX Monthly then Continue buys the monthly product', (t) async {
      await _openPaywall(t, await _service(), tier: PaywallTier.max);
      await t.tap(find.text('Outlay MAX Monthly'));
      await t.pumpAndSettle();
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(store.bought, [SubscriptionService.kMaxMonthlyId]);
    });

    testWidgets('changing tier forgets the old selection, so Pro and MAX are never mixed', (t) async {
      await _openPaywall(t, await _service());
      await t.tap(find.text('Outlay Pro Monthly'));
      await t.tap(find.text('MAX'));
      await t.pumpAndSettle();
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(store.bought, [SubscriptionService.kMaxAnnualId]);
    });

    testWidgets('without MAX in the store there is no switch, and asking for MAX does not sell Pro', (t) async {
      await _openPaywall(t, await _service(products: _pro), tier: PaywallTier.max);
      expect(find.text('MAX is not available to buy yet. Check back soon.'), findsOneWidget);
      expect(find.text('Outlay Pro Annual'), findsNothing);
      expect(find.text('Outlay Pro Monthly'), findsNothing);
      final continueButton = t.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Continue'));
      expect(continueButton.onPressed, isNull);
      expect(store.bought, isEmpty);
    });

    testWidgets('without MAX in the store the normal Pro paywall has no tier switch', (t) async {
      await _openPaywall(t, await _service(products: _pro));
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(find.text('MAX'), findsNothing);
      expect(find.text('Outlay Pro Annual'), findsOneWidget);
    });

    testWidgets('a MAX subscriber opens on MAX with their plan marked current', (t) async {
      await _openPaywall(t, await _service(plan: 'maxAnnual'));
      expect(find.text('Upgrade to MAX'), findsOneWidget);
      expect(find.text('CURRENT PLAN'), findsOneWidget);
      expect(find.text('Continue'), findsNothing); // subscribers act on the cards
    });

    testWidgets('a Pro subscriber can move to MAX with one tap on a MAX plan', (t) async {
      await _openPaywall(t, await _service(plan: 'proAnnual'));
      expect(find.text('CURRENT PLAN'), findsOneWidget);
      await t.tap(find.text('MAX'));
      await t.pumpAndSettle();
      expect(find.text('CURRENT PLAN'), findsNothing);
      await t.tap(find.text('Outlay MAX Annual'));
      await t.pumpAndSettle();
      expect(store.bought, [SubscriptionService.kMaxAnnualId]);
    });

    testWidgets('a MAX subscriber looking at the Pro tab sees no current plan there', (t) async {
      await _openPaywall(t, await _service(plan: 'maxMonthly'));
      await t.tap(find.text('Pro'));
      await t.pumpAndSettle();
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(find.text('CURRENT PLAN'), findsNothing);
    });
  });
}
