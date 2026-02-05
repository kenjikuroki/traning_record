import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../settings_manager.dart';

class IAPService {
  static final IAPService instance = IAPService._();
  IAPService._();

  static const String premiumUnlockId = 'ttraining_premium_unlock_lifetime';

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  
  /// 購入処理中かどうか
  final ValueNotifier<bool> isBusy = ValueNotifier(false);

  Future<void> init() async {
    final bool available = await _iap.isAvailable();
    _isAvailable = available;

    if (!available) {
      debugPrint('[IAPService] Store not available');
      return;
    }

    // Set up purchase stream listener
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) => debugPrint('[IAPService] Error in purchase stream: $error'),
    );

    // Initialize products
    await _loadProducts();
    
    // Check previously purchased items (optional, usually handled by restoration/backend)
    // For lifetime unlock, we can also call restorePurchases periodically or on demand.
  }

  Future<void> _loadProducts() async {
    final ProductDetailsResponse response = await _iap.queryProductDetails({premiumUnlockId});
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[IAPService] Product NOT found: ${response.notFoundIDs}');
    }
    _products = response.productDetails;
    debugPrint('[IAPService] Products loaded: ${_products.length}');
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI if needed
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint('[IAPService] Purchase error: ${purchaseDetails.error}');
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                 purchaseDetails.status == PurchaseStatus.restored) {
        // Validation logic can go here (Receipt validation)
        
        // Mark as premium
        await SettingsManager.setPremium(true);
        isBusy.value = false; // 成功・リストア時は解除
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        isBusy.value = false; // キャンセル時も解除
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }
    }
  }

  Future<bool> purchasePremium() async {
    if (!_isAvailable || isBusy.value) return false;
    
    isBusy.value = true;
    try {
      ProductDetails? premiumProduct;
      try {
        premiumProduct = _products.firstWhere((p) => p.id == premiumUnlockId);
      } catch (_) {
        // Reload if not found
        await _loadProducts();
        try {
          premiumProduct = _products.firstWhere((p) => p.id == premiumUnlockId);
        } catch (e) {
          debugPrint('[IAPService] Premium product not found after reload');
          isBusy.value = false; // 失敗時は解除
          return false;
        }
      }

      final PurchaseParam purchaseParam = PurchaseParam(productDetails: premiumProduct);
      final bool success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!success) {
        isBusy.value = false; // 購入リクエスト自体が失敗した場合は即解除
      }
      return success;
    } catch (e) {
      isBusy.value = false; // 例外発生時も解除
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!_isAvailable || isBusy.value) return;
    isBusy.value = true;
    try {
      await _iap.restorePurchases();
    } finally {
      isBusy.value = false;
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}
