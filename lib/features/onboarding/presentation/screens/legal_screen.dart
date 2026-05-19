import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/config/constants.dart';

class LegalScreen extends ConsumerStatefulWidget {
  const LegalScreen({super.key});

  @override
  ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen> {
  bool _acceptTerms = false;
  bool _isAdult = false;
  bool _loading = false;

  Future<void> _accept() async {
    if (!_acceptTerms || !_isAdult) return;
    setState(() => _loading = true);
    try {
      final userId =
          ref.read(authRepositoryProvider).currentUser!.uid;
      await ref.read(authRepositoryProvider).updateUserDocument(userId, {
        'legalAccepted': {
          'privacyVersion': AppConstants.privacyVersion,
          'termsVersion': AppConstants.termsVersion,
          'acceptedAt': FieldValue.serverTimestamp(),
        }
      });
      if (mounted) context.go('/onboarding/notifications');
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Error al guardar: inténtalo de nuevo');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Términos y privacidad')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Antes de empezar',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              CheckboxListTile(
                value: _isAdult,
                onChanged: (v) => setState(() => _isAdult = v ?? false),
                title: const Text('Soy mayor de 18 años'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _acceptTerms,
                onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                title: Wrap(
                  children: [
                    const Text('Acepto los '),
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse('https://m0nty3dev.github.io/suenobebe/privacy.html')),
                      child: Text(
                        'Términos de Uso',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Text(' y la '),
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse('https://m0nty3dev.github.io/suenobebe/privacy.html')),
                      child: Text(
                        'Política de Privacidad',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const Spacer(),
              AppButton(
                label: 'Continuar',
                onPressed:
                    (_acceptTerms && _isAdult) ? _accept : null,
                loading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
