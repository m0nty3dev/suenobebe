import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../baby/presentation/controllers/current_baby_provider.dart';
import '../../../baby/data/baby_repository.dart';
import '../../../baby/domain/models/baby.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';

class BabySettingsScreen extends ConsumerStatefulWidget {
  const BabySettingsScreen({super.key});

  @override
  ConsumerState<BabySettingsScreen> createState() => _BabySettingsScreenState();
}

class _BabySettingsScreenState extends ConsumerState<BabySettingsScreen> {
  final _nameCtrl = TextEditingController();
  BabySex? _sex;
  DateTime? _birthDate;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final baby = ref.read(currentBabyProvider).valueOrNull;
    if (baby != null) {
      _nameCtrl.text = baby.name;
      _sex = baby.sex;
      _birthDate = baby.birthDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? now.subtract(const Duration(days: 90)),
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      locale: const Locale('es'),
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final baby = ref.read(currentBabyProvider).valueOrNull;
    if (baby == null) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showErrorSnackbar(context, 'El nombre no puede estar vacío');
      return;
    }

    setState(() => _loading = true);
    try {
      final updates = <String, dynamic>{
        'name': name,
        'sex': (_sex ?? baby.sex).name,
        if (baby.photoUrl != null) 'photoUrl': baby.photoUrl,
        if (_birthDate != null &&
            !_birthDate!.isAtSameMomentAs(baby.birthDate))
          'birthDate': Timestamp.fromDate(_birthDate!),
      };

      await ref.read(babyRepositoryProvider).updateBaby(baby.id, updates);

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

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _ageLabel(DateTime birthDate) {
    final now = DateTime.now();
    var months = (now.year - birthDate.year) * 12 + (now.month - birthDate.month);
    if (now.day < birthDate.day) months--;
    if (months < 0) months = 0;
    if (months < 1) {
      final days = now.difference(birthDate).inDays;
      return '$days ${days == 1 ? 'día' : 'días'}';
    }
    if (months < 24) return '$months ${months == 1 ? 'mes' : 'meses'}';
    final years = months ~/ 12;
    final rem = months % 12;
    if (rem == 0) return '$years ${years == 1 ? 'año' : 'años'}';
    return '$years ${years == 1 ? 'año' : 'años'} y $rem ${rem == 1 ? 'mes' : 'meses'}';
  }

  @override
  Widget build(BuildContext context) {
    final baby = ref.watch(currentBabyProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Datos del bebé')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 16),

              // Birth date — shown and editable
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha de nacimiento',
                    suffixIcon: Icon(
                      Icons.edit_calendar_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_birthDate != null
                          ? _formatDate(_birthDate!)
                          : baby?.birthDate != null
                              ? _formatDate(baby!.birthDate)
                              : 'Sin fecha'),
                      if (_birthDate != null || baby?.birthDate != null)
                        Text(
                          _ageLabel(_birthDate ?? baby!.birthDate),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.55),
                              ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sex selector
              if (_sex != null) ...[
                Text('Sexo', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
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
              ],

              if (_birthDate != null &&
                  baby?.birthDate != null &&
                  !_birthDate!.isAtSameMomentAs(baby!.birthDate))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Cambiar la fecha de nacimiento ajustará las predicciones '
                    'de siesta y los horarios estimados.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),

              const SizedBox(height: 32),
              AppButton(label: 'Guardar', onPressed: _save, loading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}
