import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/services/notifications/notification_service.dart';
import '../../../../core/widgets/app_button.dart';

class NotificationsPermissionScreen extends ConsumerWidget {
  const NotificationsPermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              const PhosphorIcon(
                PhosphorIconsFill.bell,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'Notificaciones',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Te avisaremos si llevas más de 3 horas sin registrar nada durante el día. Perfecto para no olvidar ninguna siesta o toma.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Sin interrupciones entre las 22:00 y las 8:00.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                label: 'Activar notificaciones',
                onPressed: () async {
                  await NotificationService.requestPermission();
                  if (context.mounted) context.go('/home');
                },
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Ahora no',
                onPressed: () => context.go('/home'),
                outlined: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

