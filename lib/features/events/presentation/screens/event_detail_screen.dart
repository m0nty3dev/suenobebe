import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../data/events_repository.dart';
import '../../domain/models/baby_event.dart';
import '../../domain/models/event_type.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/config/constants.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/services/analytics/analytics_service.dart';
import '../../../../app/theme/app_colors.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.eventId,
    required this.babyId,
  });

  final String eventId;
  final String babyId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  BabyEvent? _event;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  DateTime? _editStartAt;
  DateTime? _editEndAt;
  final _noteCtrl = TextEditingController();
  final _mlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _mlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final event = await ref
          .read(eventsRepositoryProvider)
          .fetchEvent(widget.babyId, widget.eventId);
      if (mounted) {
        setState(() {
          _event = event;
          _loading = false;
          _noteCtrl.text = event?.metadata.note ?? '';
          _mlCtrl.text = event?.metadata.bottleMl?.toString() ?? '';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    if (_event == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: const Text('¿Borrar este evento? No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar',
                style: TextStyle(color: AppColors.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final repo = ref.read(eventsRepositoryProvider);
    final eventType = _event!.type.name;

    try {
      await repo.deleteEvent(widget.babyId, widget.eventId);
      AnalyticsService.logEventDeleted(eventType);
      if (mounted) router.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Error al eliminar el evento')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_event == null) return;
    final eventTypeName = _event!.type.name;
    setState(() => _saving = true);
    try {
      // Use callable CF so overlap validation runs server-side (§8.4).
      final callable = FirebaseFunctions
          .instanceFor(region: AppConstants.firebaseRegion)
          .httpsCallable('updateEventCallable');

      final args = <String, dynamic>{
        'babyId': widget.babyId,
        'eventId': widget.eventId,
        if (_editStartAt != null)
          'startAt': _editStartAt!.millisecondsSinceEpoch,
        if (_editEndAt != null)
          'endAt': _editEndAt!.millisecondsSinceEpoch,
        if (_noteCtrl.text.isNotEmpty) 'note': _noteCtrl.text,
        if (_event!.type == EventType.bottle && _mlCtrl.text.isNotEmpty)
          'bottleMl': int.tryParse(_mlCtrl.text),
      };

      await callable.call(args);
      await _load();
      if (mounted) {
        setState(() {
          _editing = false;
          _editStartAt = null;
          _editEndAt = null;
        });
        AnalyticsService.logEventEdited(eventTypeName);
        showSuccessSnackbar(context, 'Evento actualizado');
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) showErrorSnackbar(context, e.message ?? 'Error al guardar');
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_event?.type.label ?? 'Evento'),
        actions: [
          if (_event != null)
            IconButton(
              onPressed: _delete,
              icon: const PhosphorIcon(PhosphorIconsRegular.trash,
                  color: AppColors.errorColor),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _event == null
              ? const Center(child: Text('Evento no encontrado'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final e = _event!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: e.type.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(e.type.icon, color: e.type.color),
                const SizedBox(width: 8),
                Text(e.type.label,
                    style: TextStyle(
                        color: e.type.color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Inicio'),
            subtitle: Text(
              AppDateUtils.formatTime(_editStartAt ?? e.startAt) +
                  ' · ' +
                  AppDateUtils.formatShortDate(_editStartAt ?? e.startAt),
            ),
            trailing: _editing
                ? IconButton(
                    icon: const PhosphorIcon(PhosphorIconsRegular.clock),
                    onPressed: () async {
                      final base = _editStartAt ?? e.startAt;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(base),
                      );
                      if (time != null && mounted) {
                        setState(() => _editStartAt = DateTime(
                              base.year, base.month, base.day,
                              time.hour, time.minute,
                            ));
                      }
                    },
                  )
                : null,
          ),
          if (e.endAt != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fin'),
              subtitle: Text(
                AppDateUtils.formatTime(_editEndAt ?? e.endAt!) +
                    ' · ' +
                    AppDateUtils.formatShortDate(_editEndAt ?? e.endAt!),
              ),
              trailing: _editing
                  ? IconButton(
                      icon: const PhosphorIcon(PhosphorIconsRegular.clock),
                      onPressed: () async {
                        final base = _editEndAt ?? e.endAt!;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(base),
                        );
                        if (time != null && mounted) {
                          setState(() => _editEndAt = DateTime(
                                base.year, base.month, base.day,
                                time.hour, time.minute,
                              ));
                        }
                      },
                    )
                  : null,
            ),
          if (e.durationSec != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Duración'),
              subtitle: Text(AppDateUtils.formatDuration(
                  Duration(seconds: e.durationSec!))),
            ),
          if (e.type == EventType.nursing &&
              (e.metadata.leftDurationSec != null ||
                  e.metadata.rightDurationSec != null))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Desglose por pecho'),
              subtitle: Text([
                if (e.metadata.leftDurationSec != null)
                  'Izq: ${AppDateUtils.formatDuration(Duration(seconds: e.metadata.leftDurationSec!))}',
                if (e.metadata.rightDurationSec != null)
                  'Der: ${AppDateUtils.formatDuration(Duration(seconds: e.metadata.rightDurationSec!))}',
              ].join(' · ')),
            ),
          if (e.type == EventType.bottle && _editing)
            TextFormField(
              controller: _mlCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad (ml)'),
            )
          else if (e.type == EventType.bottle && e.metadata.bottleMl != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cantidad'),
              subtitle: Text('${e.metadata.bottleMl} ml'),
            ),
          const SizedBox(height: 16),
          if (_editing)
            TextFormField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Nota'),
            )
          else if (e.metadata.note?.isNotEmpty == true)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nota'),
              subtitle: Text(e.metadata.note!),
            ),
          const SizedBox(height: 32),
          if (_editing) ...[
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52)),
              child: _saving
                  ? const CircularProgressIndicator(color: AppColors.onPrimaryLight)
                  : const Text('Guardar cambios'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() {
                _editing = false;
                _editStartAt = null;
                _editEndAt = null;
              }),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52)),
              child: const Text('Cancelar'),
            ),
          ] else
            ElevatedButton.icon(
              onPressed: () => setState(() => _editing = true),
              icon: const PhosphorIcon(PhosphorIconsRegular.pencil),
              label: const Text('Editar'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52)),
            ),
        ],
      ),
    );
  }
}

