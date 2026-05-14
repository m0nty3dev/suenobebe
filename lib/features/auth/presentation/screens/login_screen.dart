import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../controllers/auth_controller.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../app/theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _showEmailForm = false;
  bool _isRegistering = false;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen<AsyncValue<void>>(authControllerProvider, (_, next) {
      if (next.hasError) {
        showErrorSnackbar(context, 'Error: ${next.error}');
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Center(
                child: PhosphorIcon(
                  PhosphorIconsFill.moon,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Sueño Bebé',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Registra el sueño y alimentación de tu bebé',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),
              if (!_showEmailForm) ...[
                AppButton(
                  label: 'Continuar con Google',
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signInWithGoogle(),
                  loading: authState.isLoading,
                  icon: const PhosphorIcon(PhosphorIconsRegular.googleLogo),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Continuar con email',
                  onPressed: () => setState(() => _showEmailForm = true),
                  outlined: true,
                  icon: const PhosphorIcon(PhosphorIconsRegular.envelope),
                ),
              ] else ...[
                _buildEmailForm(authState),
              ],
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Al continuar, aceptas los Términos de Uso\ny la Política de Privacidad',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm(AsyncValue<void> authState) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (_isRegistering)
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Introduce tu nombre' : null,
            ),
          if (_isRegistering) const SizedBox(height: 12),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) =>
                v == null || !v.contains('@') ? 'Email inválido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Contraseña'),
            validator: (v) => v == null || v.length < 6
                ? 'Mínimo 6 caracteres'
                : null,
          ),
          const SizedBox(height: 20),
          AppButton(
            label: _isRegistering ? 'Crear cuenta' : 'Iniciar sesión',
            loading: authState.isLoading,
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              if (_isRegistering) {
                await ref
                    .read(authControllerProvider.notifier)
                    .createUserWithEmail(
                      _emailCtrl.text.trim(),
                      _passwordCtrl.text,
                      _nameCtrl.text.trim(),
                    );
              } else {
                await ref
                    .read(authControllerProvider.notifier)
                    .signInWithEmail(
                      _emailCtrl.text.trim(),
                      _passwordCtrl.text,
                    );
              }
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () =>
                setState(() => _isRegistering = !_isRegistering),
            child: Text(
              _isRegistering
                  ? '¿Ya tienes cuenta? Inicia sesión'
                  : '¿No tienes cuenta? Regístrate',
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _showEmailForm = false),
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }
}

