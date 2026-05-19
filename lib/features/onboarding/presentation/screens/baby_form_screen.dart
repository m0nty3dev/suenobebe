import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:io';
import '../../../baby/domain/models/baby.dart';
import '../../../baby/data/baby_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/services/storage/storage_service.dart';

class BabyFormScreen extends ConsumerStatefulWidget {
  const BabyFormScreen({super.key});

  @override
  ConsumerState<BabyFormScreen> createState() => _BabyFormScreenState();
}

class _BabyFormScreenState extends ConsumerState<BabyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  DateTime? _birthDate;
  BabySex _sex = BabySex.other;
  File? _photoFile;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _photoFile = File(picked.path));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 90)),
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      locale: const Locale('es'),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      showErrorSnackbar(context, 'Selecciona la fecha de nacimiento');
      return;
    }

    setState(() => _loading = true);
    try {
      final userId = ref.read(authRepositoryProvider).currentUser!.uid;
      String? photoUrl;

      if (_photoFile != null) {
        photoUrl = await ref
            .read(storageServiceProvider)
            .uploadBabyPhoto(babyId: 'temp_$userId', file: _photoFile!);
      }

      final baby = await ref.read(babyRepositoryProvider).createBaby(
            name: _nameCtrl.text.trim(),
            birthDate: _birthDate!,
            sex: _sex,
            adminId: userId,
            photoUrl: photoUrl,
          );

      await ref
          .read(authRepositoryProvider)
          .updateUserDocument(userId, {'currentBabyId': baby.id});

      if (mounted) context.go('/onboarding/legal');
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: CircleAvatar(
                      radius: 52,
                      backgroundImage: _photoFile != null
                          ? FileImage(_photoFile!) as ImageProvider
                          : null,
                      child: _photoFile == null
                          ? const PhosphorIcon(
                              PhosphorIconsRegular.camera,
                              size: 36,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(child: Text('Añadir foto (opcional)')),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre del bebé'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Introduce el nombre' : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha de nacimiento',
                    ),
                    child: Text(
                      _birthDate != null
                          ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                          : 'Seleccionar fecha',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Sexo', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: BabySex.values
                      .map((sex) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text(sex == BabySex.male
                                    ? 'Niño'
                                    : sex == BabySex.female
                                        ? 'Niña'
                                        : 'Otro'),
                                selected: _sex == sex,
                                onSelected: (_) =>
                                    setState(() => _sex = sex),
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: 'Continuar',
                  onPressed: _submit,
                  loading: _loading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
