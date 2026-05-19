import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../baby/presentation/controllers/current_baby_provider.dart';
import '../../../../core/config/constants.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/analytics/analytics_service.dart';

// Cached once per ProviderScope lifetime — avoids re-calling on every rebuild.
final _packageInfoProvider = FutureProvider<PackageInfo>(
  (_) => PackageInfo.fromPlatform(),
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baby = ref.watch(currentBabyProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          _SectionHeader('Bebé'),
          ListTile(
            leading: const PhosphorIcon(PhosphorIconsRegular.baby),
            title: Text(baby?.name ?? 'Datos del bebé'),
            trailing: const PhosphorIcon(PhosphorIconsRegular.caretRight),
            onTap: () => context.push('/settings/baby'),
          ),
          ListTile(
            leading: const PhosphorIcon(PhosphorIconsRegular.users),
            title: const Text('Cuidadores'),
            trailing: const PhosphorIcon(PhosphorIconsRegular.caretRight),
            onTap: () => context.push('/settings/caregivers'),
          ),
          const Divider(),
          _SectionHeader('Cuenta'),
          ListTile(
            leading: const PhosphorIcon(PhosphorIconsRegular.star),
            title: const Text('Suscripción'),
            trailing: const PhosphorIcon(PhosphorIconsRegular.caretRight),
            onTap: () => context.push('/settings/subscription'),
          ),
          ListTile(
            leading: const PhosphorIcon(PhosphorIconsRegular.bell),
            title: const Text('Notificaciones'),
            trailing: const PhosphorIcon(PhosphorIconsRegular.caretRight),
            onTap: () => context.push('/settings/notifications'),
          ),
          ListTile(
            leading: const PhosphorIcon(PhosphorIconsRegular.palette),
            title: const Text('Tema'),
            trailing: const PhosphorIcon(PhosphorIconsRegular.caretRight),
            onTap: () => context.push('/settings/theme'),
          ),
          const Divider(),
          _SectionHeader('Datos'),
          ListTile(
            leading: const PhosphorIcon(PhosphorIconsRegular.export),
            title: const Text('Exportar mis datos'),
            onTap: () => _exportData(context, ref),
          ),
          const Divider(),
          _SectionHeader('Legal'),
          ListTile(
            leading: const PhosphorIcon(PhosphorIconsRegular.fileText),
            title: const Text('Términos y Privacidad'),
            trailing: const PhosphorIcon(PhosphorIconsRegular.arrowSquareOut),
            onTap: () => launchUrl(
              Uri.parse('https://m0nty3dev.github.io/suenobebe/privacy.html'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            leading: const PhosphorIcon(PhosphorIconsRegular.info),
            title: const Text('Versión'),
            trailing: Text(
              ref.watch(_packageInfoProvider).valueOrNull?.version ?? '—',
            ),
          ),
          const Divider(),
          ListTile(
            leading: const PhosphorIcon(PhosphorIconsRegular.signOut),
            title: const Text('Cerrar sesión'),
            onTap: () => _signOut(context, ref),
          ),
          ListTile(
            leading: const PhosphorIcon(
              PhosphorIconsRegular.trash,
              color: AppColors.errorColor,
            ),
            title: const Text(
              'Borrar cuenta',
              style: TextStyle(color: AppColors.errorColor),
            ),
            onTap: () => context.push('/settings/delete-account'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cerrar sesión',
      message: '¿Seguro que quieres cerrar sesión?',
      confirmLabel: 'Cerrar sesión',
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    showSuccessSnackbar(context, 'Generando exportación…');
    try {
      final functions = FirebaseFunctions.instanceFor(
          region: AppConstants.firebaseRegion);
      final result =
          await functions.httpsCallable('exportUserData').call();
      final url = result.data['url'] as String?;
      if (url != null) {
        await launchUrl(Uri.parse(url),
            mode: LaunchMode.externalApplication);
        AnalyticsService.logExportData();
      }
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, 'Error: $e');
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

