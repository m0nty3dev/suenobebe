import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../baby/presentation/controllers/current_baby_provider.dart';
import '../../../baby/domain/models/baby.dart';

class SubscriptionStatusScreen extends ConsumerWidget {
  const SubscriptionStatusScreen({super.key});

  String _statusLabel(SubscriptionStatus s) {
    switch (s) {
      case SubscriptionStatus.none:
        return 'Sin suscripción';
      case SubscriptionStatus.trial:
        return 'Periodo de prueba';
      case SubscriptionStatus.trialExpired:
        return 'Prueba expirada';
      case SubscriptionStatus.active:
        return 'Activa';
      case SubscriptionStatus.grace:
        return 'Periodo de gracia';
      case SubscriptionStatus.onHold:
        return 'En espera';
      case SubscriptionStatus.cancelled:
        return 'Cancelada';
      case SubscriptionStatus.expired:
        return 'Expirada';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baby = ref.watch(currentBabyProvider).valueOrNull;
    if (baby == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final sub = baby.subscription;

    return Scaffold(
      appBar: AppBar(title: const Text('Suscripción')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: const Text('Estado'),
                trailing: Text(_statusLabel(sub.status)),
                contentPadding: EdgeInsets.zero,
              ),
              if (sub.plan != null)
                ListTile(
                  title: const Text('Plan'),
                  trailing: Text(sub.plan == SubscriptionPlan.annual
                      ? 'Anual'
                      : 'Mensual'),
                  contentPadding: EdgeInsets.zero,
                ),
              if (sub.expiresAt != null)
                ListTile(
                  title: const Text('Próxima renovación'),
                  trailing: Text(
                      DateFormat('d MMM yyyy', 'es').format(sub.expiresAt!)),
                  contentPadding: EdgeInsets.zero,
                ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => launchUrl(Uri.parse(
                    'https://play.google.com/store/account/subscriptions')),
                child: const Text('Gestionar en Google Play'),
              ),
              const SizedBox(height: 12),
              if (sub.status == SubscriptionStatus.none ||
                  sub.status == SubscriptionStatus.expired ||
                  sub.status == SubscriptionStatus.trialExpired)
                ElevatedButton(
                  onPressed: () => context.push('/paywall?source=settings'),
                  child: const Text('Suscribirme'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
