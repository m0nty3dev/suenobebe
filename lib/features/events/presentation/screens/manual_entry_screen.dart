import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../domain/models/baby_event.dart';
import '../../domain/models/event_type.dart';
import '../../domain/usecases/create_event.dart';
import '../../domain/usecases/validate_no_overlap.dart';
import '../../data/events_repository.dart';
import '../../../baby/presentation/controllers/current_baby_provider.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';

class ManualEntryScreen extends ConsumerStatefulWidget {
  const ManualEntryScreen({super.key, this.initialType});

  final String? initialType;

  @override
  ConsumerState<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends ConsumerState<ManualEntryScreen> {
  late EventType _type;
  late DateTime _startAt;
  DateTime? _endAt;
  int? _bottleMl;
  bool _loading = false;
  final _noteCtrl = TextEditingController();
  final _mlCtrl = TextEditingController();

  bool get _typePreSelected => widget.initialType != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType != null
        ? EventType.fromFirestore(widget.initialType!)
        : EventType.nap;

    // Default start time = active day at current time
    final activeDay = ref.read(activeDayProvider);
    final now = DateTime.now();
    _startAt = DateTime(activeDay.year, activeDay.month, activeDay.day, now.hour, now.minute);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _mlCtrl.dispose();
    super.dispose();
  }

  // ─── time picker (time only; date fixed to active day) ────────────────────

  Future<void> _pickTime(bool isStart) async {
    final activeDay = ref.read(activeDayProvider);
    final initial = isStart ? _startAt : (_endAt ?? _startAt);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final result = DateTime(
      activeDay.year, activeDay.month, activeDay.day,
      time.hour, time.minute,
    );
    setState(() {
      if (isStart) {
        _startAt = result;
        if (_endAt != null && !_endAt!.isAfter(result)) _endAt = null;
      } else {
        _endAt = result;
      }
    });
  }

  // ─── save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final babyId = ref.read(currentBabyIdProvider);
    final userId = ref.read(authStateProvider).valueOrNull?.uid;
    if (babyId == null || userId == null) return;

    // Validate end time when provided for duration events
    if (_type.isDuration && _endAt != null && !_endAt!.isAfter(_startAt)) {
      showErrorSnackbar(context, 'La hora de fin debe ser posterior al inicio');
      return;
    }

    setState(() => _loading = true);
    try {
      final activeDay = ref.read(activeDayProvider);
      final dayKey = AppDateUtils.toDayKey(activeDay);
      final repo = ref.read(eventsRepositoryProvider);

      if (_type.isDuration && _endAt == null) {
        // Create as live event via callable CF (handles closing existing live,
        // trial.firstEventAt, and caregiver check atomically)
        final validate = ValidateNoOverlap(repo);
        final useCase = CreateEvent(repo, validate);
        await useCase.callLive(
          babyId: babyId,
          userId: userId,
          type: _type,
          dayKey: dayKey,
          startAt: _startAt,
          metadata: _type == EventType.nursing
              ? const EventMetadata(breast: 'left', leftDurationSec: 0, rightDurationSec: 0)
              : null,
        );
      } else {
        // Create as completed event (end time given, or instant event)
        final validate = ValidateNoOverlap(repo);
        final useCase = CreateEvent(repo, validate);
        await useCase.callManual(
          babyId: babyId,
          userId: userId,
          type: _type,
          startAt: _startAt,
          endAt: _type.isDuration ? _endAt : _startAt,
          dayKey: dayKey,
          bottleMl: _type == EventType.bottle && _endAt != null
              ? int.tryParse(_mlCtrl.text.trim())
              : null,
          note: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
        );
      }

      if (mounted) {
        showSuccessSnackbar(context, 'Evento registrado');
        context.pop();
      }
    } on CreateEventException catch (e) {
      if (mounted) showErrorSnackbar(context, e.message);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final activeDay = ref.watch(activeDayProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_typePreSelected ? _type.label : 'Introducir manualmente'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selector (only when not pre-selected)
              if (!_typePreSelected) ...[
                Text('Tipo de evento',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: EventType.values
                      .map((t) => ChoiceChip(
                            label: Text(t.label),
                            selected: _type == t,
                            onSelected: (_) => setState(() {
                              _type = t;
                              _endAt = null;
                            }),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
              ],

              // Active day (read-only)
              Text(
                AppDateUtils.formatDate(activeDay),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
              ),
              const SizedBox(height: 8),

              // Start time
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hora de inicio'),
                subtitle: Text(AppDateUtils.formatTime(_startAt)),
                trailing: const PhosphorIcon(PhosphorIconsRegular.clock),
                onTap: () => _pickTime(true),
              ),

              // End time (only for duration events, optional)
              if (_type.isDuration) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hora de fin'),
                  subtitle: _endAt != null
                      ? Text(AppDateUtils.formatTime(_endAt!))
                      : Text(
                          'Opcional — sin fin: se crea como activo',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.45),
                            fontSize: 12,
                          ),
                        ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_endAt != null)
                        IconButton(
                          icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 18),
                          onPressed: () => setState(() => _endAt = null),
                          tooltip: 'Quitar hora de fin',
                        ),
                      const PhosphorIcon(PhosphorIconsRegular.clock),
                    ],
                  ),
                  onTap: () => _pickTime(false),
                ),
              ],

              // Bottle ml (only when bottle + end time provided)
              if (_type == EventType.bottle && _endAt != null) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _mlCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad (ml)',
                    hintText: 'Ej: 120',
                    suffixText: 'ml',
                  ),
                ),
              ],

              // Note
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Nota (opcional)'),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: _type.isDuration && _endAt == null
                    ? 'Iniciar ahora'
                    : 'Guardar',
                onPressed: _save,
                loading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

