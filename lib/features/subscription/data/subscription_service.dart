import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart' show ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/subscription_status.dart';

const _subscriptionsChannel = MethodChannel('com.outlay.app/subscriptions');

/// An influencer discount code resolved via the server. Android's
/// discounted price still comes live from the already-fetched Play Billing
/// catalog — Google's "Developer determined" offers stay eligible for
/// brand-new customers, so the original live-lookup design holds there. iOS
/// switched away from Apple Promotional Offers (which turned out to be
/// ineligible for anyone who's never subscribed before — most of an
/// influencer's actual audience) to a native Offer Code, which has no
/// queryable local-catalog entry to read a live price from, so its
/// discountedPriceLabel is server-supplied text instead of a live value.
class AppliedOffer {
  const AppliedOffer({
    required this.code,
    required this.product,
    required this.offerId,
    required this.discountedPriceLabel,
    this.androidOfferToken,
  });

  final String code;
  final ProductDetails product;
  final String offerId;
  final String discountedPriceLabel;
  // Only set on Android — the opaque token Play Billing requires at
  // purchase time. iOS instead hands the real Apple code straight to the
  // App Store via a redemption URL — see SubscriptionService.redeemOffer.
  final String? androidOfferToken;
}

/// What happened when a purchase or plan change was started.
enum BuyOutcome {
  /// The store's purchase sheet was opened (a new purchase, or a change that takes effect now).
  started,

  /// A downgrade was accepted and will take effect at the end of the current billing period.
  switchScheduled,

  /// Nothing was started; see [SubscriptionService.error].
  failed,
}

class SubscriptionService extends ChangeNotifier {
  // debugProducts skips the real _init()/IAP plugin call entirely and
  // seeds _products directly — the plugin talks to a platform channel
  // with no real store behind it in `flutter test`, so it's otherwise
  // impossible to get PaywallScreen showing real product data (title,
  // formatted price) in a widget test. Production call sites never pass
  // this; only tests exercising the real product list against the real
  // widget tree do, e.g. paywall_screen_layout_test.dart. Not annotated
  // @visibleForTesting since the constructor itself is also the normal
  // production entry point (see main.dart) — only the parameter is
  // test-only, not the constructor as a whole.
  SubscriptionService(this._prefs, {List<ProductDetails>? debugProducts}) {
    _pendingPlan = SubscriptionPlan.values.where((p) => p.name == _prefs.getString(_kPendingPlan)).firstOrNull;
    if (debugProducts != null) {
      _products = debugProducts;
      _storeAvailable = true;
      _loading = false;
    } else {
      _init();
    }
  }

  final SharedPreferences _prefs;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  StreamSubscription<AuthState>? _authSub;

  // Product IDs — must match exactly what you register in App Store Connect
  // and Google Play Console.
  static const String kProMonthlyId = 'expense_tracker_pro_monthly';
  static const String kProAnnualId = 'expense_tracker_pro_annual';
  static const String kMaxMonthlyId = 'expense_tracker_max_monthly';
  static const String kMaxAnnualId = 'expense_tracker_max_annual';
  /// Every product StoreKit is asked about when checking what the user currently has. MAX must be included:
  /// a MAX subscriber looks like "nothing active" to a Pro-only query, which would downgrade them to free.
  static const List<String> entitlementProductIds = [kProMonthlyId, kProAnnualId, kMaxMonthlyId, kMaxAnnualId];
  static const Set<String> _kProductIds = {
    kProMonthlyId,
    kProAnnualId,
    kMaxMonthlyId,
    kMaxAnnualId,
  };

  // SharedPreferences keys. _kScanMonth/_kScanCount are a display cache of
  // the server-authoritative count in Supabase's scan_counts table — never
  // the source of truth for whether a scan is allowed (see
  // tryIncrementScan). Kept local-only so the free-tier badge/limit sheet
  // don't need a network round trip on every rebuild.
  static const _kPlan = 'sub_plan';
  static const _kScanMonth = 'scan_month';
  static const _kScanCount = 'scan_count';
  static const _kPendingPlan = 'sub_pending_plan';

  List<ProductDetails> _products = [];
  bool _storeAvailable = false;
  bool _loading = true;
  String? _error;
  DateTime? _expirationDate;
  bool? _willAutoRenew;
  SubscriptionPlan? _pendingPlan;

  List<ProductDetails> get products => _products;
  bool get storeAvailable => _storeAvailable;
  bool get loading => _loading;
  String? get error => _error;

  SubscriptionStatus get status {
    final planStr = _prefs.getString(_kPlan) ?? 'free';
    final plan = SubscriptionPlan.values.firstWhere(
      (p) => p.name == planStr,
      orElse: () => SubscriptionPlan.free,
    );
    return SubscriptionStatus(
      plan: plan,
      scansThisMonth: _scansThisMonth(),
      expiresAt: _expirationDate,
      willAutoRenew: _willAutoRenew,
      pendingPlan: _pendingPlan,
    );
  }

  ProductDetails? get monthlyProduct => _basePlanProduct(kProMonthlyId);

  ProductDetails? get annualProduct => _basePlanProduct(kProAnnualId);

  ProductDetails? get maxMonthlyProduct => _basePlanProduct(kMaxMonthlyId);

  ProductDetails? get maxAnnualProduct => _basePlanProduct(kMaxAnnualId);

  /// Android's queryProductDetails returns one [GooglePlayProductDetails]
  /// per *offer* on a subscription (base plan + every configured offer,
  /// e.g. an influencer discount), all sharing the same product id — not
  /// one entry per product the way iOS/other platforms work. A plain
  /// `.firstOrNull` by id has no guarantee of landing on the undiscounted
  /// base plan rather than whichever offer happens to come first in Play's
  /// response, which is exactly what silently showed a discounted price as
  /// the *default*, before any code was ever entered. This instead
  /// explicitly picks the entry whose offer has no offerId — Play's own
  /// signal for "this is the base plan, not a discount" (see
  /// SubscriptionOfferDetailsWrapper.offerId) — and only falls back to
  /// firstOrNull where that distinction doesn't apply (iOS).
  ProductDetails? _basePlanProduct(String id) {
    final matches = _products.where((p) => p.id == id);
    if (!Platform.isIOS) {
      for (final p in matches) {
        if (p is GooglePlayProductDetails) {
          final idx = p.subscriptionIndex;
          final offers = p.productDetails.subscriptionOfferDetails;
          if (idx != null && offers != null && offers[idx].offerId == null) {
            return p;
          }
        }
      }
    }
    return matches.firstOrNull;
  }

  /// The plan a store product id stands for, or null for a product we do not sell.
  static SubscriptionPlan? planFromProductId(String? productId) {
    return productId == kMaxAnnualId
        ? SubscriptionPlan.maxAnnual
        : productId == kMaxMonthlyId
            ? SubscriptionPlan.maxMonthly
            : productId == kProAnnualId
                ? SubscriptionPlan.proAnnual
                : productId == kProMonthlyId
                    ? SubscriptionPlan.proMonthly
                    : null;
  }

  Future<void> _init() async {
    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) {
      _loading = false;
      notifyListeners();
      return;
    }

    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) => debugPrint('[IAP] stream error: $e'),
    );

    // The first sync above often runs before anyone is signed in, so there is nobody to attach the entitlement to.
    // Run it again when a user signs in.
    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedIn) unawaited(refreshEntitlement());
      });
    } catch (e) {
      debugPrint('[SubscriptionService] auth listener unavailable: $e');
    }

    await _loadProducts();
    // Without this, a real subscriber's local "Pro" flag only ever gets set
    // by actually completing a purchase in this exact app session — on iOS,
    // StoreKit doesn't replay past transactions into purchaseStream unless
    // restorePurchases() is explicitly called, so a fresh install or a
    // cold start after the local cache was cleared would show as free
    // forever even for a genuinely active subscriber.
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[IAP] restorePurchases failed: $e');
    }
    await _syncEntitlementFromStoreKit();
    await _syncEntitlementFromPlay();
    await _refreshScanCount();
    _loading = false;
    notifyListeners();
  }

  /// Tells the server what the store says this account holds, so a family can be tied to its admin's MAX. The body
  /// is proof the server checks with the store itself (Apple's signed transaction, or Play's purchase token), never
  /// a plan the app asserts. Best effort: it must not affect the local plan, and runs again on the next sync.
  Future<void> _reportEntitlement(Map<String, dynamic> body) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return;
      await client.functions.invoke('sync-entitlement', body: body);
    } catch (e) {
      debugPrint('[SubscriptionService] sync-entitlement failed: $e');
    }
  }

  /// Authoritative iOS entitlement check via StoreKit2 (see AppDelegate's
  /// getSubscriptionStatus), independent of whether the `in_app_purchase`
  /// plugin's purchaseStream/restorePurchases actually delivered an event
  /// this session. Only acts on a definite answer from StoreKit: a verified
  /// active subscription upgrades the local plan, and an explicit "nothing
  /// active" downgrades it — a thrown/failed native call leaves the local
  /// cache untouched rather than risking a wrong downgrade from a transient
  /// failure (no network, StoreKit unavailable, etc.).
  Future<void> _syncEntitlementFromStoreKit() async {
    if (!Platform.isIOS) return;
    try {
      final result = await _subscriptionsChannel.invokeMethod<Map>(
        'getSubscriptionStatus',
        {
          'productIds': entitlementProductIds,
        },
      );
      if (result == null) {
        _willAutoRenew = null;
        _expirationDate = null;
        _pendingPlan = null;
        if (status.plan != SubscriptionPlan.free) {
          await _prefs.setString(_kPlan, SubscriptionPlan.free.name);
          notifyListeners();
        }
        return;
      }
      final productId = result['productId'] as String?;
      final plan = planFromProductId(productId);
      if (plan != null) {
        await _prefs.setString(_kPlan, plan.name);
        final signedTransaction = result['signedTransaction'] as String?;
        if (signedTransaction != null) {
          unawaited(_reportEntitlement({'store': 'apple', 'signedTransaction': signedTransaction}));
        }
      }
      _willAutoRenew = result['willAutoRenew'] as bool?;
      final millis = result['expirationDateMillis'] as num?;
      _expirationDate =
          millis != null ? DateTime.fromMillisecondsSinceEpoch(millis.toInt()) : null;
      // The plan that will actually bill at the next renewal — differs from
      // the currently-active `plan` exactly when a downgrade/crossgrade
      // (e.g. Annual → Monthly) is pending but hasn't taken effect yet.
      final autoRenewProductId = result['autoRenewProductId'] as String?;
      _pendingPlan = planFromProductId(autoRenewProductId);
      notifyListeners();
    } catch (e) {
      debugPrint('[SubscriptionService] getSubscriptionStatus failed: $e');
    }
  }

  /// Public wrapper so main.dart can call this right after sign-in (see
  /// _onAuthChanged) — SubscriptionService itself is constructed once at
  /// app startup, before the user has necessarily signed in yet, so the
  /// _init()-time refresh below can run with no uid at all and leave the
  /// "X scans left" badge showing a stale/default cached value (0, or
  /// whatever a previous account left behind) until the user's first
  /// scan happens to correct it via tryIncrementScan. Signing in doesn't
  /// reconstruct this service, so nothing else would ever re-trigger this
  /// refresh otherwise.
  Future<void> refreshScanCount() => _refreshScanCount();

  /// Pulls this month's scan count from Supabase into the local display
  /// cache. Not the enforcement point (tryIncrementScan is) — just keeps
  /// the "X scans left" badge accurate after e.g. a scan on another
  /// device. Silently no-ops when signed out or offline; the cache simply
  /// stays whatever it last was.
  Future<void> _refreshScanCount() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final month = _currentMonth();
      final row = await Supabase.instance.client
          .from('scan_counts')
          .select('count')
          .eq('user_id', uid)
          .eq('month', month)
          .maybeSingle();
      await _prefs.setString(_kScanMonth, month);
      await _prefs.setInt(_kScanCount, (row?['count'] as int?) ?? 0);
      notifyListeners();
    } catch (e) {
      debugPrint('[SubscriptionService] scan count refresh failed: $e');
    }
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(_kProductIds);
      if (response.error != null) {
        _error = response.error!.message;
      }
      _products = response.productDetails;
    } catch (e) {
      _error = e.toString();
    }
  }

  /// Test hooks: pretend to be Android, and supply the subscriptions Google Play reports as active.
  @visibleForTesting
  static bool? debugIsAndroid;
  @visibleForTesting
  Future<List<GooglePlayPurchaseDetails>> Function()? debugActivePurchases;

  bool get _isAndroid => debugIsAndroid ?? Platform.isAndroid;

  /// Everything Google Play reports for this account. Throws when Play answers with an error, so a failed lookup is
  /// never mistaken for "no subscription" (which would drop a paying user's plan, or let a switch double-bill).
  Future<List<GooglePlayPurchaseDetails>> _queryPlayPurchases() async {
    final hook = debugActivePurchases;
    if (hook != null) return hook();
    final response = await _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().queryPastPurchases();
    return purchasesOrThrow(response);
  }

  /// The purchases in a Play answer, or an exception if the answer was an error.
  @visibleForTesting
  static List<GooglePlayPurchaseDetails> purchasesOrThrow(QueryPurchaseDetailsResponse response) {
    final error = response.error;
    if (error != null) throw Exception('Google Play lookup failed: ${error.message}');
    return response.pastPurchases.whereType<GooglePlayPurchaseDetails>().toList();
  }

  /// Our subscriptions that are active right now, highest plan first.
  List<GooglePlayPurchaseDetails> _activeOurs(List<GooglePlayPurchaseDetails> all) => all
      .where((p) => p.status == PurchaseStatus.purchased && planFromProductId(p.productID) != null)
      .toList()
    ..sort((a, b) => planRank(planFromProductId(b.productID)!).compareTo(planRank(planFromProductId(a.productID)!)));

  Future<List<GooglePlayPurchaseDetails>> _activePlayPurchases() async => _activeOurs(await _queryPlayPurchases());

  /// Android counterpart of the StoreKit check: makes the stored plan match what Google Play says the account has,
  /// so a lapsed subscription stops counting as paid and one bought on another device starts to.
  ///
  /// It only acts on a definite answer. If Play cannot be reached or answers with an error, nothing changes. It never
  /// downgrades while a purchase is still pending, or while Play lists an active product this app does not recognise,
  /// because either could be a paying user the lookup does not fully describe.
  Future<void> _syncEntitlementFromPlay() async {
    if (!_isAndroid) return;
    try {
      final all = await _queryPlayPurchases();
      final active = _activeOurs(all);

      if (active.isNotEmpty) {
        final best = active.first;
        final plan = planFromProductId(best.productID)!;
        await _prefs.setString(_kPlan, plan.name);
        _willAutoRenew = best.billingClientPurchase.isAutoRenewing;
        unawaited(_reportEntitlement({
          'store': 'google',
          'productId': best.productID,
          'purchaseToken': best.billingClientPurchase.purchaseToken,
        }));
        if (_pendingPlan == plan) {
          _pendingPlan = null;
          await _prefs.remove(_kPendingPlan);
        }
        notifyListeners();
        return;
      }

      final pendingOurs = all.any((p) => p.status == PurchaseStatus.pending && planFromProductId(p.productID) != null);
      final unknownActive = all.any((p) => p.status == PurchaseStatus.purchased && planFromProductId(p.productID) == null);
      if (pendingOurs || unknownActive) return;

      // Definitely nothing active.
      _willAutoRenew = null;
      _expirationDate = null;
      _pendingPlan = null;
      await _prefs.remove(_kPendingPlan);
      if (status.plan != SubscriptionPlan.free) {
        await _prefs.setString(_kPlan, SubscriptionPlan.free.name);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[SubscriptionService] Play entitlement check failed: $e');
    }
  }

  Future<BuyOutcome> buy(ProductDetails product) async {
    // Clear any previous failure before starting a new attempt — otherwise
    // a stale error from an earlier purchase/switch keeps showing even
    // after this new attempt succeeds (or fails for a different reason).
    _error = null;
    try {
      PurchaseParam param = PurchaseParam(productDetails: product);
      var scheduled = false;

      // On Android each plan is its own subscription. Buying a second one without saying which it replaces would
      // leave the user paying for both, so a change of plan always names the subscription being replaced.
      final target = planFromProductId(product.id);
      if (_isAndroid && target != null && status.isPaid && target != status.plan) {
        final active = await _activePlayPurchases();
        if (active.isEmpty) {
          // Google Play reports nothing active, so the cached plan is out of date (the subscription lapsed).
          // There is nothing to replace; this is simply a new purchase.
          await downgradeToFree();
        } else {
          final old = active.first;
          final change = planChange(planFromProductId(old.productID)!, target);
          if (change == PlanChange.none) {
            _error = 'You already have this plan.';
            notifyListeners();
            return BuyOutcome.failed;
          }
          scheduled = change == PlanChange.downgrade;
          param = GooglePlayPurchaseParam(
            productDetails: product,
            changeSubscriptionParam: ChangeSubscriptionParam(
              oldPurchaseDetails: old,
              // Up: immediately, crediting the unused time. Down: when the current period ends, so nothing already
              // paid for is lost — the same rule the App Store applies.
              replacementMode: scheduled ? ReplacementMode.deferred : ReplacementMode.withTimeProration,
            ),
          );
        }
      }

      await _iap.buyNonConsumable(purchaseParam: param);
      if (scheduled) {
        _pendingPlan = target;
        await _prefs.setString(_kPendingPlan, target!.name);
        notifyListeners();
        return BuyOutcome.switchScheduled;
      }
      return BuyOutcome.started;
    } catch (e) {
      // buyNonConsumable() only throws for a request that never even
      // launched (e.g. store unreachable) — a request that launches but is
      // then rejected by the store (declined, already subscribed via a
      // different channel, subscription-group conflict, etc.) comes back
      // as a PurchaseStatus.error event on purchaseStream instead, handled
      // in _handlePurchase below. Both paths must set _error, since
      // previously neither was ever shown to the user — a failed plan
      // switch just silently did nothing, with no way to tell it apart
      // from a UI refresh bug.
      _error = _isAndroid
          ? 'We could not check your current subscription with Google Play. Try again, or use Manage Subscription.'
          : e.toString();
      if (!_isAndroid) debugPrint('[SubscriptionService] buy failed: $e');
      notifyListeners();
      return BuyOutcome.failed;
    }
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  /// Test hook: feeds a store event through the same path the purchase stream uses.
  @visibleForTesting
  Future<void> handlePurchaseForTest(PurchaseDetails purchase) => _handlePurchase(purchase);

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      // Every product maps to its own plan. (This used to treat anything that was not Pro Annual as Pro
      // Monthly, which would have recorded a MAX purchase as Pro.)
      final plan = planFromProductId(purchase.productID);
      if (plan != null) {
        await _prefs.setString(_kPlan, plan.name);
        // A scheduled change (Android) has taken effect once the store reports the plan it was waiting for.
        if (_pendingPlan == plan) {
          _pendingPlan = null;
          await _prefs.remove(_kPendingPlan);
        }
        notifyListeners();
      }
    } else if (purchase.status == PurchaseStatus.error) {
      _error = purchase.error?.message ?? 'Purchase failed';
      notifyListeners();
    }

    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  // Called when a Supabase subscription lapses (future: server-side verify).
  Future<void> downgradeToFree() async {
    await _prefs.setString(_kPlan, SubscriptionPlan.free.name);
    notifyListeners();
  }

  /// Atomically checks-and-increments the monthly scan counter server-side
  /// (Supabase `increment_scan_count` RPC) and returns whether the scan is
  /// allowed. This — not the local cache — is the actual enforcement point:
  /// the count lives per-account in Postgres specifically so uninstalling
  /// and reinstalling, or scanning from a second device, can't reset or
  /// dodge the limit the way a SharedPreferences-only counter could.
  ///
  /// Called once per scan the user actually keeps (see ScanFab — only after
  /// OCR found data AND the user tapped "Use These Values"), not on every
  /// attempt, so a failed read or a discarded scan doesn't cost a credit.
  ///
  /// On a network/server failure, falls back to the last-known local cache
  /// rather than blocking the user outright — but that cache is exactly
  /// what resets to 0 after an uninstall/reinstall (SharedPreferences is
  /// wiped), which would silently reopen the reinstall loophole this whole
  /// mechanism exists to close. So on failure this first tries a plain
  /// server read (_refreshScanCount) to get the account's real count before
  /// ever trusting the local cache — only a device that's genuinely
  /// offline (both the increment and the plain read fail) falls all the
  /// way back to local-only behavior.
  Future<bool> tryIncrementScan() async {
    if (status.isPaid) return true;
    try {
      final result = await Supabase.instance.client.rpc(
        'increment_scan_count',
        params: {'p_limit': SubscriptionStatus.freeScansPerMonth},
      ) as Map<String, dynamic>;
      await _prefs.setString(_kScanMonth, _currentMonth());
      await _prefs.setInt(_kScanCount, result['count'] as int);
      notifyListeners();
      return result['allowed'] as bool;
    } catch (e) {
      debugPrint('[SubscriptionService] scan count RPC failed: $e');
      await _refreshScanCount();
      return status.canScan;
    }
  }

  /// Public wrapper so screens (Settings, Paywall) can force a fresh
  /// StoreKit check on mount — e.g. after returning from the background,
  /// where the subscription could have changed without this session seeing
  /// a purchaseStream event for it.
  Future<void> refreshEntitlement() async {
    await _syncEntitlementFromStoreKit();
    await _syncEntitlementFromPlay();
  }

  /// Opens the platform's native subscription management screen so the user
  /// can view billing details, change plan, or cancel — the App Store /
  /// Play Store don't allow cancellation to happen inside a third-party app
  /// directly, so this hands off to the platform instead of building that
  /// UI ourselves.
  ///
  /// On iOS, tries StoreKit2's native manage-subscriptions sheet first —
  /// this correctly respects the current App Store environment, showing
  /// sandbox subscriptions when running via TestFlight/Xcode and real ones
  /// once the app is live, unlike a web link to apps.apple.com which only
  /// ever shows production data. Falls back to the web URL if the native
  /// call is unavailable (e.g. iOS < 15) or fails.
  Future<bool> openManageSubscriptions() async {
    if (Platform.isIOS) {
      try {
        final handled = await _subscriptionsChannel
            .invokeMethod<bool>('showManageSubscriptions');
        if (handled == true) {
          // The user may have just changed or cancelled their plan in that
          // native sheet — re-check StoreKit rather than leaving the local
          // cache showing whatever it was before they opened it.
          unawaited(_syncEntitlementFromStoreKit());
          return true;
        }
      } catch (e) {
        debugPrint('[SubscriptionService] native showManageSubscriptions failed: $e');
      }
    }
    final uri = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse('https://play.google.com/store/account/subscriptions'
            '?package=com.outlay.app');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[SubscriptionService] openManageSubscriptions failed: $e');
      return false;
    }
  }

  /// Resolves a human-typed influencer code against the resolve-offer-code
  /// Edge Function. Android matches the response against the corresponding
  /// offer already present in the locally-fetched product catalog
  /// (queryProductDetails already pulled every offer on each product, so
  /// this needs no further network call to know the discounted price). iOS
  /// has no local catalog entry to match against — a native Offer Code
  /// isn't part of StoreKit's queryable catalog — so it uses the
  /// server-supplied description and product id directly. Returns null on
  /// any failure — invalid code, inactive code, unknown product — since the
  /// paywall only needs a single "not valid" state.
  Future<AppliedOffer?> lookupOfferCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'resolve-offer-code',
        body: {'code': trimmed, 'platform': platform},
      );
      final data = response.data as Map?;
      final offerId = data?['offerId'] as String?;
      if (offerId == null) return null;
      if (Platform.isIOS) {
        final productId = data?['productId'] as String?;
        final description = data?['discountDescription'] as String?;
        if (productId == null || description == null) return null;
        final product = _products.where((p) => p.id == productId).firstOrNull;
        if (product == null) return null;
        return AppliedOffer(
          code: trimmed,
          product: product,
          offerId: offerId,
          discountedPriceLabel: description,
        );
      }
      return _matchOfferInCatalog(trimmed, offerId);
    } catch (e) {
      debugPrint('[SubscriptionService] lookupOfferCode failed: $e');
      return null;
    }
  }

  /// Android-only — see [lookupOfferCode] for why iOS doesn't go through a
  /// catalog match at all.
  AppliedOffer? _matchOfferInCatalog(String code, String offerId) {
    for (final product in _products) {
      if (product is GooglePlayProductDetails) {
        final offers = product.productDetails.subscriptionOfferDetails ?? [];
        for (final offer in offers) {
          if (offer.offerId == offerId) {
            return AppliedOffer(
              code: code,
              product: product,
              offerId: offerId,
              discountedPriceLabel: offer.pricingPhases.first.formattedPrice,
              androidOfferToken: offer.offerIdToken,
            );
          }
        }
      }
    }
    return null;
  }

  /// Redeems a resolved [AppliedOffer]. Android still purchases in-app
  /// using the offer token from [lookupOfferCode] — Google's "Developer
  /// determined" offers stay eligible for brand-new customers, so nothing
  /// changed there. iOS hands the real Apple code straight to the App
  /// Store via its direct redemption URL instead of an in-app purchase:
  /// Apple's in-app redemption sheet can't be pre-filled with a code (the
  /// user would have to retype it), and there's no signed-purchase path
  /// available here at all — unlike Promotional Offers, native Offer Codes
  /// aren't part of StoreKit's purchase API, Apple handles the charge
  /// itself once the user completes redemption in the App Store app. This
  /// app finds out about the resulting entitlement the normal way
  /// afterward (restore/StoreKit sync, App Store Server Notification),
  /// same as openManageSubscriptions.
  Future<void> redeemOffer(AppliedOffer offer) async {
    _error = null;
    if (Platform.isIOS) {
      final uri = Uri.parse(
        'https://apps.apple.com/redeem'
        '?ctx=offercodes'
        '&id=${AppConstants.appleAppStoreId}'
        '&code=${Uri.encodeComponent(offer.offerId)}',
      );
      try {
        final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!opened) _error = 'Could not open the App Store to redeem this code';
      } catch (e) {
        _error = e.toString();
      }
      notifyListeners();
      return;
    }
    try {
      final param = GooglePlayPurchaseParam(
        productDetails: offer.product,
        offerToken: offer.androidOfferToken,
      );
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  int _scansThisMonth() {
    final savedMonth = _prefs.getString(_kScanMonth);
    if (savedMonth != _currentMonth()) return 0;
    return _prefs.getInt(_kScanCount) ?? 0;
  }

  String _currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
