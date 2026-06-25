import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/error_translator.dart';
import '../domain/subscription_status.dart';

class SubscriptionService extends ChangeNotifier {
  SubscriptionService(this._prefs) {
    _init();
  }

  final SharedPreferences _prefs;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  // Product IDs — must match exactly what you register in App Store Connect
  // and Google Play Console.
  static const String kProMonthlyId = 'expense_tracker_pro_monthly';
  static const String kProAnnualId = 'expense_tracker_pro_annual';
  static const Set<String> _kProductIds = {kProMonthlyId, kProAnnualId};

  // SharedPreferences keys
  static const _kPlan = 'sub_plan';
  static const _kScanMonth = 'scan_month';
  static const _kScanCount = 'scan_count';

  List<ProductDetails> _products = [];
  bool _storeAvailable = false;
  bool _loading = true;
  String? _error;

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
    );
  }

  ProductDetails? get monthlyProduct =>
      _products.where((p) => p.id == kProMonthlyId).firstOrNull;

  ProductDetails? get annualProduct =>
      _products.where((p) => p.id == kProAnnualId).firstOrNull;

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

    await _loadProducts();
    _loading = false;
    notifyListeners();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(_kProductIds);
      if (response.error != null) {
        _error = response.error!.message;
      }
      _products = response.productDetails;
    } catch (e) {
      _error = friendlyErrorMessage(e);
    }
  }

  Future<void> buy(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  void _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      final plan = purchase.productID == kProAnnualId
          ? SubscriptionPlan.proAnnual
          : SubscriptionPlan.proMonthly;
      await _prefs.setString(_kPlan, plan.name);
      notifyListeners();
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

  /// Increments the monthly scan counter. Returns false if limit reached.
  Future<bool> tryIncrementScan() async {
    if (status.isPro) return true;
    if (!status.canScan) return false;
    final month = _currentMonth();
    await _prefs.setString(_kScanMonth, month);
    await _prefs.setInt(_kScanCount, _scansThisMonth() + 1);
    notifyListeners();
    return true;
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
    super.dispose();
  }
}
