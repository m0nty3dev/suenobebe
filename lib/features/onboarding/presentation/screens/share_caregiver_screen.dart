import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/widgets/app_button.dart';

class ShareCaregiverScreen extends ConsumerWidget {
  const ShareCaregiverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('¿Compartes el cuidado?')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Cuidas al bebé con alguien más?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Puedes invitar a otra persona para que comparta el registro.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              _OptionCard(
                icon: PhosphorIconsRegular.shareNetwork,
                title: 'Crear código de invitación',
                subtitle: 'Genera un código para enviar al otro cuidador',
                onTap: () => context.go('/settings/caregivers'),
              ),
              const SizedBox(height: 12),
              _OptionCard(
                icon: PhosphorIconsRegular.key,
                title: 'Tengo un código',
                subtitle: 'Únete al perfil de un bebé existente',
                onTap: () => context.go('/invite/redeem'),
              ),
              const Spacer(),
              AppButton(
                label: 'Más tarde',
                onPressed: () => context.go('/onboarding/legal'),
                outlined: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final PhosphorIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: PhosphorIcon(icon, size: 28),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: const PhosphorIcon(PhosphorIconsRegular.caretRight),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
