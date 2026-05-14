import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/invitations_repository.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';

class RedeemCodeScreen extends ConsumerStatefulWidget {
  const RedeemCodeScreen({super.key});

  @override
  ConsumerState<RedeemCodeScreen> createState() => _RedeemCodeScreenState();
}

class _RedeemCodeScreenState extends ConsumerState<RedeemCodeScreen> {
  final _codeCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _aliasCtrl.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_codeCtrl.text.trim().length != 6) {
      showErrorSnackbar(context, 'El código debe tener 6 dígitos');
      return;
    }
    if (_aliasCtrl.text.trim().isEmpty) {
      showErrorSnackbar(context, 'Introduce tu alias (ej: Papá, Mamá)');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(invitationsRepositoryProvider).acceptInvitation(
            _codeCtrl.text.trim(),
            _aliasCtrl.text.trim(),
          );
      if (mounted) {
        showSuccessSnackbar(context, 'Te has unido al bebé');
        context.go('/home');
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Código inválido o caducado');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unirme a un bebé')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Introduce el código de invitación de 6 dígitos que te compartieron.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Código de 6 dígitos',
                  counterText: '',
                ),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _aliasCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tu alias (ej: Papá, Mamá, Abuela)',
                ),
              ),
              const SizedBox(height: 32),
              AppButton(
                  label: 'Unirme',
                  onPressed: _redeem,
                  loading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}
