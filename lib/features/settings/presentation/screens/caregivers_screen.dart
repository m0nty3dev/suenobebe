import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import '../../../baby/presentation/controllers/current_baby_provider.dart';
import '../../../invitations/data/invitations_repository.dart';
import '../../../../core/widgets/app_snackbar.dart';

class CaregiversScreen extends ConsumerWidget {
  const CaregiversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baby = ref.watch(currentBabyProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Cuidadores')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (baby != null) ...[
                Text('Cuidadores actuales',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...baby.caregiversInfo.entries.map(
                  (e) => ListTile(
                    leading: const CircleAvatar(
                        child: PhosphorIcon(PhosphorIconsRegular.user)),
                    title: Text(e.value.alias),
                    subtitle: Text(
                        e.value.role == 'admin' ? 'Admin' : 'Cuidador'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (baby != null && baby.caregivers.length < 2)
                ElevatedButton.icon(
                  onPressed: () => _createCode(context, ref, baby.id),
                  icon: const PhosphorIcon(
                      PhosphorIconsRegular.shareNetwork),
                  label: const Text('Generar código de invitación'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createCode(
      BuildContext context, WidgetRef ref, String babyId) async {
    try {
      final code = await ref
          .read(invitationsRepositoryProvider)
          .createInvitation(babyId);
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Código de invitación'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  code,
                  style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8),
                ),
                const SizedBox(height: 8),
                const Text('Comparte este código. Caduca en 24 horas.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  showSuccessSnackbar(context, 'Código copiado');
                },
                child: const Text('Copiar'),
              ),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar')),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, 'Error: $e');
    }
  }
}
