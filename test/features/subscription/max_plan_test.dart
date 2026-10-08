import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
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
  final params = <PurchaseParam>[];

  // Enough of a store for SubscriptionService to start up against it.
  @override
  Future<bool> isAvailable() async => true;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async =>
      ProductDetailsResponse(productDetails: const [], notFoundIDs: const []);
  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    bought.add(purchaseParam.productDetails.id);
    params.add(purchaseParam);
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

/// A subscription Google Play reports as active.
GooglePlayPurchaseDetails _active(String productId, {String token = 'old-token', bool autoRenewing = true}) {
  final wrapper = PurchaseWrapper(
    orderId: 'GPA.1', packageName: 'com.outlay.app', purchaseTime: 1, purchaseToken: token, signature: 's',
    products: [productId], isAutoRenewing: autoRenewing, originalJson: '{}', isAcknowledged: true,
    purchaseState: PurchaseStateWrapper.purchased,
  );
  return GooglePlayPurchaseDetails.fromPurchase(wrapper).single;
}

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

  group('changing plan on Android', () {
    setUp(() => SubscriptionService.debugIsAndroid = true);
    tearDown(() => SubscriptionService.debugIsAndroid = null);

    ProductDetails prod(String id) => [..._pro, ..._max].firstWhere((p) => p.id == id);

    test('Pro to MAX replaces the Pro subscription immediately, crediting the unused time', () async {
      final svc = await _service(plan: 'proMonthly');
      svc.debugActivePurchases = () async => [_active(SubscriptionService.kProMonthlyId)];

      final outcome = await svc.buy(prod(SubscriptionService.kMaxAnnualId));
      expect(outcome, BuyOutcome.started);

      final param = store.params.single as GooglePlayPurchaseParam;
      expect(param.productDetails.id, SubscriptionService.kMaxAnnualId);
      final change = param.changeSubscriptionParam!;
      expect(change.oldPurchaseDetails.productID, SubscriptionService.kProMonthlyId);
      expect(change.oldPurchaseDetails.billingClientPurchase.purchaseToken, 'old-token');
      expect(change.replacementMode, ReplacementMode.withTimeProration);
      expect(svc.status.pendingPlan, isNull);
    });

    test('Pro Monthly to Pro Annual is an upgrade too, so it also replaces the old subscription', () async {
      final svc = await _service(plan: 'proMonthly');
      svc.debugActivePurchases = () async => [_active(SubscriptionService.kProMonthlyId)];
      await svc.buy(prod(SubscriptionService.kProAnnualId));
      final change = (store.params.single as GooglePlayPurchaseParam).changeSubscriptionParam!;
      expect(change.replacementMode, ReplacementMode.withTimeProration);
    });

    test('MAX to Pro is a downgrade: it waits for the end of the paid period and is remembered', () async {
      final svc = await _service(plan: 'maxAnnual');
      svc.debugActivePurchases = () async => [_active(SubscriptionService.kMaxAnnualId)];

      final outcome = await svc.buy(prod(SubscriptionService.kProMonthlyId));
      expect(outcome, BuyOutcome.switchScheduled);

      final change = (store.params.single as GooglePlayPurchaseParam).changeSubscriptionParam!;
      expect(change.replacementMode, ReplacementMode.deferred);
      // Still MAX until the period ends, with the switch queued.
      expect(svc.status.plan, SubscriptionPlan.maxAnnual);
      expect(svc.status.pendingPlan, SubscriptionPlan.proMonthly);
      expect(svc.status.hasPendingPlanChange, isTrue);
    });

    test('a queued switch survives a restart and clears once the store reports the new plan', () async {
      final svc = await _service(plan: 'maxAnnual');
      svc.debugActivePurchases = () async => [_active(SubscriptionService.kMaxAnnualId)];
      await svc.buy(prod(SubscriptionService.kProMonthlyId));

      final prefs = await SharedPreferences.getInstance();
      final restarted = SubscriptionService(prefs, debugProducts: [..._pro, ..._max]);
      expect(restarted.status.pendingPlan, SubscriptionPlan.proMonthly);

      await restarted.handlePurchaseForTest(_purchase(SubscriptionService.kProMonthlyId));
      expect(restarted.status.plan, SubscriptionPlan.proMonthly);
      expect(restarted.status.pendingPlan, isNull);
    });

    test('the store replaying the old purchase does not apply the queued downgrade early', () async {
      final svc = await _service(plan: 'maxAnnual');
      svc.debugActivePurchases = () async => [_active(SubscriptionService.kMaxAnnualId)];
      await svc.buy(prod(SubscriptionService.kProMonthlyId));
      await svc.handlePurchaseForTest(_purchase(SubscriptionService.kMaxAnnualId, status: PurchaseStatus.restored));
      expect(svc.status.plan, SubscriptionPlan.maxAnnual);
      expect(svc.status.pendingPlan, SubscriptionPlan.proMonthly);
    });

    test('with two active subscriptions the highest one is the one replaced', () async {
      final svc = await _service(plan: 'maxMonthly');
      svc.debugActivePurchases = () async => [
            _active(SubscriptionService.kProMonthlyId, token: 'pro-token'),
            _active(SubscriptionService.kMaxMonthlyId, token: 'max-token'),
          ];
      await svc.buy(prod(SubscriptionService.kMaxAnnualId));
      final change = (store.params.single as GooglePlayPurchaseParam).changeSubscriptionParam!;
      expect(change.oldPurchaseDetails.billingClientPurchase.purchaseToken, 'max-token');
    });

    test('asking for the plan Play says you already have buys nothing, even if the cached plan is stale', () async {
      // The app's cache still says Pro Annual, but Google Play says MAX Monthly is active.
      final svc = await _service(plan: 'proAnnual');
      svc.debugActivePurchases = () async => [_active(SubscriptionService.kMaxMonthlyId)];
      final outcome = await svc.buy(prod(SubscriptionService.kMaxMonthlyId));
      expect(outcome, BuyOutcome.failed);
      expect(svc.error, 'You already have this plan.');
      expect(store.bought, isEmpty);
    });

    test('if Google Play cannot be reached nothing is bought, so there is no double subscription', () async {
      final svc = await _service(plan: 'proMonthly');
      svc.debugActivePurchases = () async => throw Exception('billing unavailable');
      final outcome = await svc.buy(prod(SubscriptionService.kMaxAnnualId));
      expect(outcome, BuyOutcome.failed);
      expect(store.bought, isEmpty);
      expect(svc.error, contains('Google Play'));
    });

    test('a lapsed subscription (Play shows none) is treated as a new purchase, not a replacement', () async {
      final svc = await _service(plan: 'proAnnual');
      svc.debugActivePurchases = () async => [];
      final outcome = await svc.buy(prod(SubscriptionService.kMaxMonthlyId));
      expect(outcome, BuyOutcome.started);
      final param = store.params.single;
      expect(param is GooglePlayPurchaseParam && param.changeSubscriptionParam != null, isFalse);
      expect(svc.status.plan, SubscriptionPlan.free); // the stale plan was dropped
    });

    test('a free user simply buys, with no lookup at all', () async {
      final svc = await _service();
      var lookedUp = false;
      svc.debugActivePurchases = () async {
        lookedUp = true;
        return [];
      };
      await svc.buy(prod(SubscriptionService.kMaxAnnualId));
      expect(lookedUp, isFalse);
      expect(store.bought, [SubscriptionService.kMaxAnnualId]);
    });

    test('a pending or unknown purchase is never chosen as the one to replace', () async {
      final svc = await _service(plan: 'proMonthly');
      final pending = GooglePlayPurchaseDetails(
        productID: SubscriptionService.kMaxMonthlyId,
        verificationData: PurchaseVerificationData(localVerificationData: '', serverVerificationData: 'p', source: 's'),
        transactionDate: null,
        billingClientPurchase: PurchaseWrapper(
          orderId: 'x', packageName: 'p', purchaseTime: 1, purchaseToken: 'p', signature: 's',
          products: [SubscriptionService.kMaxMonthlyId], isAutoRenewing: true, originalJson: '{}', isAcknowledged: false,
          purchaseState: PurchaseStateWrapper.pending,
        ),
        status: PurchaseStatus.pending,
      );
      svc.debugActivePurchases = () async => [pending, _active('some_other_product'), _active(SubscriptionService.kProMonthlyId)];
      await svc.buy(prod(SubscriptionService.kMaxAnnualId));
      final change = (store.params.single as GooglePlayPurchaseParam).changeSubscriptionParam!;
      expect(change.oldPurchaseDetails.productID, SubscriptionService.kProMonthlyId);
    });
  });

  group('Android startup check against Google Play', () {
    setUp(() => SubscriptionService.debugIsAndroid = true);
    tearDown(() => SubscriptionService.debugIsAndroid = null);

    GooglePlayPurchaseDetails pendingPurchase(String id) => GooglePlayPurchaseDetails(
          productID: id,
          verificationData: PurchaseVerificationData(localVerificationData: '', serverVerificationData: 'p', source: 's'),
          transactionDate: null,
          billingClientPurchase: PurchaseWrapper(
            orderId: 'x', packageName: 'p', purchaseTime: 1, purchaseToken: 'p', signature: 's',
            products: [id], isAutoRenewing: true, originalJson: '{}', isAcknowledged: false,
            purchaseState: PurchaseStateWrapper.pending,
          ),
          status: PurchaseStatus.pending,
        );

    Future<SubscriptionService> check(String? cached, Future<List<GooglePlayPurchaseDetails>> Function() play) async {
      final svc = await _service(plan: cached);
      svc.debugActivePurchases = play;
      await svc.refreshEntitlement();
      return svc;
    }

    test('a lapsed subscription (Play lists nothing) drops the stored plan to free', () async {
      final svc = await check('proAnnual', () async => []);
      expect(svc.status.plan, SubscriptionPlan.free);
      expect(svc.status.isPaid, isFalse);
    });

    test('a lapsed MAX subscription also loses the Family perks', () async {
      final svc = await check('maxMonthly', () async => []);
      expect(svc.status.isMax, isFalse);
      expect(svc.status.canCreateFamily, isFalse);
    });

    test('an active subscription keeps the plan', () async {
      final svc = await check('proMonthly', () async => [_active(SubscriptionService.kProMonthlyId)]);
      expect(svc.status.plan, SubscriptionPlan.proMonthly);
    });

    test('a plan bought on another device is picked up', () async {
      final svc = await check(null, () async => [_active(SubscriptionService.kMaxMonthlyId)]);
      expect(svc.status.plan, SubscriptionPlan.maxMonthly);
      expect(svc.status.isMax, isTrue);
    });

    test('if the plan on the phone is wrong, Play wins', () async {
      final svc = await check('maxAnnual', () async => [_active(SubscriptionService.kProMonthlyId)]);
      expect(svc.status.plan, SubscriptionPlan.proMonthly);
    });

    test('with two active subscriptions the highest plan counts', () async {
      final svc = await check(null, () async => [_active(SubscriptionService.kProAnnualId), _active(SubscriptionService.kMaxMonthlyId)]);
      expect(svc.status.plan, SubscriptionPlan.maxMonthly);
    });

    test('a subscription that is switched off (will not renew) is shown as ending, still paid until then', () async {
      final svc = await check('proMonthly', () async => [_active(SubscriptionService.kProMonthlyId, autoRenewing: false)]);
      expect(svc.status.isPaid, isTrue);
      expect(svc.status.willAutoRenew, isFalse);
    });

    test('a queued downgrade that has now taken effect is cleared', () async {
      final svc = await _service(plan: 'maxAnnual');
      svc.debugActivePurchases = () async => [_active(SubscriptionService.kMaxAnnualId)];
      await svc.buy([..._pro, ..._max].firstWhere((p) => p.id == SubscriptionService.kProMonthlyId));
      expect(svc.status.pendingPlan, SubscriptionPlan.proMonthly);

      svc.debugActivePurchases = () async => [_active(SubscriptionService.kProMonthlyId)];
      await svc.refreshEntitlement();
      expect(svc.status.plan, SubscriptionPlan.proMonthly);
      expect(svc.status.pendingPlan, isNull);
    });

    test('a queued downgrade is dropped when the subscription has lapsed altogether', () async {
      final svc = await _service(plan: 'maxAnnual');
      svc.debugActivePurchases = () async => [_active(SubscriptionService.kMaxAnnualId)];
      await svc.buy([..._pro, ..._max].firstWhere((p) => p.id == SubscriptionService.kProMonthlyId));
      svc.debugActivePurchases = () async => [];
      await svc.refreshEntitlement();
      expect(svc.status.plan, SubscriptionPlan.free);
      expect(svc.status.pendingPlan, isNull);
    });

    test('if Google Play cannot be reached nothing changes', () async {
      final svc = await check('proAnnual', () async => throw Exception('billing unavailable'));
      expect(svc.status.plan, SubscriptionPlan.proAnnual);
    });

    test('an error answer from Play is not mistaken for "no subscription"', () {
      expect(
        () => SubscriptionService.purchasesOrThrow(QueryPurchaseDetailsResponse(
            pastPurchases: const [], error: IAPError(source: 'test', code: 'x', message: 'Service unavailable'))),
        throwsA(isA<Exception>()),
      );
      expect(SubscriptionService.purchasesOrThrow(QueryPurchaseDetailsResponse(pastPurchases: [_active(SubscriptionService.kProMonthlyId)])), hasLength(1));
    });

    test('a purchase still pending blocks a downgrade', () async {
      final svc = await check('proAnnual', () async => [pendingPurchase(SubscriptionService.kProAnnualId)]);
      expect(svc.status.plan, SubscriptionPlan.proAnnual);
    });

    test('an active product this app does not recognise blocks a downgrade', () async {
      final svc = await check('proAnnual', () async => [_active('some_older_product')]);
      expect(svc.status.plan, SubscriptionPlan.proAnnual);
    });

    test('a free user stays free', () async {
      final svc = await check(null, () async => []);
      expect(svc.status.plan, SubscriptionPlan.free);
    });

    test('the check runs when the app starts, once the store is up', () async {
      SharedPreferences.setMockInitialValues({'sub_plan': 'proAnnual'});
      final prefs = await SharedPreferences.getInstance();
      final svc = SubscriptionService(prefs); // starts up against the fake store
      svc.debugActivePurchases = () async => [];
      // Let startup finish: store query, restore, entitlement checks.
      for (var i = 0; i < 20 && svc.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(svc.loading, isFalse);
      expect(svc.status.plan, SubscriptionPlan.free);
      svc.dispose();
    });

    test('it does nothing at all off Android', () async {
      SubscriptionService.debugIsAndroid = false;
      final svc = await check('proAnnual', () async => []);
      expect(svc.status.plan, SubscriptionPlan.proAnnual);
    });
  });

  group('plan order', () {
    test('ranks MAX Annual > MAX Monthly > Pro Annual > Pro Monthly > Free', () {
      final order = [SubscriptionPlan.free, SubscriptionPlan.proMonthly, SubscriptionPlan.proAnnual, SubscriptionPlan.maxMonthly, SubscriptionPlan.maxAnnual];
      for (var i = 0; i < order.length - 1; i++) {
        expect(planChange(order[i], order[i + 1]), PlanChange.upgrade, reason: '${order[i]} -> ${order[i + 1]}');
        expect(planChange(order[i + 1], order[i]), PlanChange.downgrade);
      }
      expect(planChange(SubscriptionPlan.maxAnnual, SubscriptionPlan.maxAnnual), PlanChange.none);
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
