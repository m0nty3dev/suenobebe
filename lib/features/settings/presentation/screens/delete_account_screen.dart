import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/config/constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/analytics/analytics_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _loading = false;

  final _functions =
      FirebaseFunctions.instanceFor(region: AppConstants.firebaseRegion);

  Future<void> _requestDeletion() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Borrar cuenta',
      message:
          'Tu cuenta se eliminará en 7 días. Puedes cancelarlo iniciando '
          'sesión durante ese periodo.',
      confirmLabel: 'Borrar mi cuenta',
      destructive: true,
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      await _functions.httpsCallable('requestAccountDeletion').call();
      AnalyticsService.logDeleteAccountRequested();
      if (mounted) {
        showSuccessSnackbar(context, 'Cuenta marcada para eliminar en 7 días');
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelDeletion() async {
    setState(() => _loading = true);
    try {
      await _functions.httpsCallable('cancelAccountDeletion').call();
      AnalyticsService.logDeleteAccountCancelled();
      if (mounted) showSuccessSnackbar(context, 'Borrado cancelado');
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Derive deletion state from Firestore — survives navigation and app restart.
    final deletionScheduled = ref
            .watch(appUserProvider)
            .valueOrNull
            ?.deletionScheduledAt !=
        null;

    return Scaffold(
      appBar: AppBar(title: const Text('Borrar cuenta')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Borrar cuenta',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: AppColors.errorColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tu cuenta y todos los datos asociados se eliminarán en 7 días. '
                'Puedes cancelar este proceso iniciando sesión durante ese periodo.',
              ),
              const SizedBox(height: 32),
              if (!deletionScheduled)
                AppButton(
                  label: 'Borrar mi cuenta',
                  onPressed: _loading ? null : _requestDeletion,
                  loading: _loading,
                  color: AppColors.errorColor,
                )
              else
                AppButton(
                  label: 'Cancelar borrado',
                  onPressed: _loading ? null : _cancelDeletion,
                  loading: _loading,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
