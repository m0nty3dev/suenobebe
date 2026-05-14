import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../baby/domain/models/baby.dart';
import '../../../baby/presentation/controllers/current_baby_provider.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/billing_repository.dart';
import '../../../../core/services/analytics/analytics_service.dart';

final canWriteProvider = Provider<bool>((ref) {
  final baby = ref.watch(currentBabyProvider).valueOrNull;
  if (baby == null) return true;
  final status = baby.subscription.status;
  return status == SubscriptionStatus.none ||
      status == SubscriptionStatus.trial ||
      status == SubscriptionStatus.active ||
      status == SubscriptionStatus.grace ||
      status == SubscriptionStatus.cancelled;
});

final showAdsProvider = Provider<bool>((ref) {
  final baby = ref.watch(currentBabyProvider).valueOrNull;
  if (baby == null) return true;
  final status = baby.subscription.status;
  return status == SubscriptionStatus.none ||
      status == SubscriptionStatus.trial ||
      status == SubscriptionStatus.trialExpired ||
      status == SubscriptionStatus.onHold ||
      status == SubscriptionStatus.expired;
});

class SubscriptionController extends AsyncNotifier<List<ProductDetails>> {
  @override
  Future<List<ProductDetails>> build() async {
    _listenPurchases();
    return ref.read(billingRepositoryProvider).loadProducts();
  }

  void _listenPurchases() {
    final sub =
        ref.read(billingRepositoryProvider).purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          final token = p.verificationData.serverVerificationData;
          await ref
              .read(billingRepositoryProvider)
              .validatePurchase(token, p.productID);
          await ref.read(billingRepositoryProvider).completePurchase(p);
          if (p.status == PurchaseStatus.purchased) {
            final plan = p.productID.contains('annual') ? 'annual' : 'monthly';
            AnalyticsService.logSubscriptionStarted(plan);
          }
        }
      }
    });
    ref.onDispose(sub.cancel);
  }

  Future<void> loadProducts() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(billingRepositoryProvider).loadProducts(),
    );
  }

  Future<void> buyProduct(ProductDetails product) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    await ref.read(billingRepositoryProvider).buyProduct(product, uid);
  }

  Future<void> restorePurchases() async {
    await ref.read(billingRepositoryProvider).restorePurchases();
  }
}

final subscriptionControllerProvider =
    AsyncNotifierProvider<SubscriptionController, List<ProductDetails>>(
        SubscriptionController.new);
