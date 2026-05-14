import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../controllers/subscription_controller.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/analytics/analytics_service.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, required this.source});
  final String source;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _selectedPlan = 'annual';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionControllerProvider.notifier).loadProducts();
      AnalyticsService.logPaywallViewed(widget.source);
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(subscriptionControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const PhosphorIcon(PhosphorIconsRegular.x),
                ),
              ),
              Center(
                child: PhosphorIcon(
                  PhosphorIconsFill.star,
                  size: 64,
                  color: AppColors.lightSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Acceso completo a Sueño Bebé',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Continúa registrando sin límites',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ...[
                (PhosphorIconsRegular.infinity, 'Registro ilimitado de eventos'),
                (PhosphorIconsRegular.prohibit, 'Sin anuncios'),
                (
                  PhosphorIconsRegular.chartLine,
                  'Estadísticas avanzadas (próximamente)'
                ),
                (PhosphorIconsRegular.brain, 'Predicciones de sueño (próximamente)'),
              ].map(
                (f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      PhosphorIcon(f.$1, color: AppColors.lightPrimary),
                      const SizedBox(width: 12),
                      Text(f.$2,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              products.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error cargando planes: $e'),
                data: (productList) =>
                    _buildPlanSelector(context, productList),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Suscribirme',
                onPressed: () =>
                    _subscribe(context, products.valueOrNull ?? []),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Restaurar compra',
                onPressed: () => ref
                    .read(subscriptionControllerProvider.notifier)
                    .restorePurchases(),
                outlined: true,
              ),
              const SizedBox(height: 16),
              Text(
                'Se renueva automáticamente. Cancela cuando quieras en Google Play.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanSelector(
      BuildContext context, List<ProductDetails> products) {
    final annual = _findProduct(products, 'sb_annual_1199');
    final monthly = _findProduct(products, 'sb_monthly_399');

    return Column(
      children: [
        if (annual != null)
          _PlanCard(
            title: 'Anual · ${annual.price}',
            subtitle: 'Ahorra 75%',
            highlighted: true,
            selected: _selectedPlan == 'annual',
            onTap: () => setState(() => _selectedPlan = 'annual'),
          ),
        const SizedBox(height: 8),
        if (monthly != null)
          _PlanCard(
            title: 'Mensual · ${monthly.price}',
            selected: _selectedPlan == 'monthly',
            onTap: () => setState(() => _selectedPlan = 'monthly'),
          ),
      ],
    );
  }

  ProductDetails? _findProduct(List<ProductDetails> products, String id) {
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _subscribe(
      BuildContext context, List<ProductDetails> products) async {
    final id =
        _selectedPlan == 'annual' ? 'sb_annual_1199' : 'sb_monthly_399';
    final product = _findProduct(products, id);
    if (product == null) {
      showErrorSnackbar(context, 'Plan no disponible');
      return;
    }
    await ref
        .read(subscriptionControllerProvider.notifier)
        .buyProduct(product);
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    this.subtitle,
    this.highlighted = false,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool highlighted;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
            if (highlighted)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Recomendado',
                    style: TextStyle(fontSize: 11, color: AppColors.onPrimaryLight)),
              ),
          ],
        ),
      ),
    );
  }
}

