import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/constants.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) => BillingRepository());

class BillingRepository {
  final _iap = InAppPurchase.instance;
  final _functions =
      FirebaseFunctions.instanceFor(region: AppConstants.firebaseRegion);

  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<bool> isAvailable() => _iap.isAvailable();

  Future<List<ProductDetails>> loadProducts() async {
    final ids = {AppConstants.productMonthly, AppConstants.productAnnual};
    final response = await _iap.queryProductDetails(ids);
    return response.productDetails;
  }

  /// [userId] is set as applicationUserName, which Play Billing maps to
  /// obfuscatedExternalAccountId. The CF verifies it matches the authenticated
  /// uid to prevent token reuse across accounts.
  Future<void> buyProduct(ProductDetails product, String userId) async {
    final param = PurchaseParam(
      productDetails: product,
      applicationUserName: userId,
    );
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  Future<void> validatePurchase(String purchaseToken, String productId) async {
    final callable = _functions.httpsCallable('validatePlayBillingPurchase');
    await callable.call({'purchaseToken': purchaseToken, 'productId': productId});
  }

  Future<void> acknowledgePurchase(String purchaseToken) async {
    final callable = _functions.httpsCallable('acknowledgePurchase');
    await callable.call({'purchaseToken': purchaseToken});
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }
}
