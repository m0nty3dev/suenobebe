import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../../baby/presentation/controllers/current_baby_provider.dart';
import '../../../baby/data/baby_repository.dart';
import '../../../baby/domain/models/baby.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/services/storage/storage_service.dart';

class BabySettingsScreen extends ConsumerStatefulWidget {
  const BabySettingsScreen({super.key});

  @override
  ConsumerState<BabySettingsScreen> createState() =>
      _BabySettingsScreenState();
}

class _BabySettingsScreenState
    extends ConsumerState<BabySettingsScreen> {
  final _nameCtrl = TextEditingController();
  BabySex? _sex;
  File? _photoFile;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final baby = ref.read(currentBabyProvider).valueOrNull;
    if (baby != null) {
      _nameCtrl.text = baby.name;
      _sex = baby.sex;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final baby = ref.read(currentBabyProvider).valueOrNull;
    if (baby == null) return;
    setState(() => _loading = true);
    try {
      String? photoUrl = baby.photoUrl;
      if (_photoFile != null) {
        photoUrl = await ref
            .read(storageServiceProvider)
            .uploadBabyPhoto(babyId: baby.id, file: _photoFile!);
      }
      await ref.read(babyRepositoryProvider).updateBaby(baby.id, {
        'name': _nameCtrl.text.trim(),
        'sex': (_sex ?? baby.sex).name,
        if (photoUrl != null) 'photoUrl': photoUrl,
      });
      if (mounted) {
        showSuccessSnackbar(context, 'Datos actualizados');
        context.pop();
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos del bebé')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 16),
              if (_sex != null)
                Row(
                  children: BabySex.values
                      .map(
                        (s) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(s == BabySex.male
                                  ? 'Niño'
                                  : s == BabySex.female
                                      ? 'Niña'
                                      : 'Otro'),
                              selected: _sex == s,
                              onSelected: (_) => setState(() => _sex = s),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 32),
              AppButton(
                  label: 'Guardar',
                  onPressed: _save,
                  loading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}
