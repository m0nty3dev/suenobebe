import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../events/domain/models/baby_event.dart';
import '../../../events/domain/models/event_type.dart';
import '../../../events/data/events_repository.dart';
import '../../../baby/presentation/controllers/current_baby_provider.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_snackbar.dart';

class LiveEventIndicator extends ConsumerStatefulWidget {
  const LiveEventIndicator({super.key, required this.event});

  final BabyEvent event;

  @override
  ConsumerState<LiveEventIndicator> createState() => _LiveEventIndicatorState();
}

class _LiveEventIndicatorState extends ConsumerState<LiveEventIndicator>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  int get _totalElapsedSec =>
      DateTime.now().difference(widget.event.startAt).inSeconds;

  int get _accLeft => widget.event.metadata.leftDurationSec ?? 0;
  int get _accRight => widget.event.metadata.rightDurationSec ?? 0;
  String get _breast => widget.event.metadata.breast ?? 'left';

  int get _currentSideSec => (_totalElapsedSec - _accLeft - _accRight).clamp(0, 999999);
  int get _displayLeft => _accLeft + (_breast == 'left' ? _currentSideSec : 0);
  int get _displayRight => _accRight + (_breast == 'right' ? _currentSideSec : 0);

  String _fmtSec(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  // ─── actions ────────────────────────────────────────────────────────────────

  Future<void> _switchSide() async {
    if (_busy) return;
    setState(() => _busy = true);
    final babyId = ref.read(currentBabyIdProvider);
    if (babyId == null) { setState(() => _busy = false); return; }

    final newLeft = _accLeft + (_breast == 'left' ? _currentSideSec : 0);
    final newRight = _accRight + (_breast == 'right' ? _currentSideSec : 0);
    final newBreast = _breast == 'left' ? 'right' : 'left';

    try {
      await ref.read(eventsRepositoryProvider).updateEvent(babyId, widget.event.id, {
        'metadata.breast': newBreast,
        'metadata.leftDurationSec': newLeft,
        'metadata.rightDurationSec': newRight,
      });
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishNursing() async {
    if (_busy) return;
    setState(() => _busy = true);
    final babyId = ref.read(currentBabyIdProvider);
    if (babyId == null) { setState(() => _busy = false); return; }

    final finalLeft = _accLeft + (_breast == 'left' ? _currentSideSec : 0);
    final finalRight = _accRight + (_breast == 'right' ? _currentSideSec : 0);
    final now = DateTime.now();

    try {
      await ref.read(eventsRepositoryProvider).updateEvent(babyId, widget.event.id, {
        'status': 'completed',
        'endAt': now,
        'durationSec': finalLeft + finalRight,
        'metadata.breast': _breast,
        'metadata.leftDurationSec': finalLeft,
        'metadata.rightDurationSec': finalRight,
      });
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Error al finalizar: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishBottle() async {
    if (_busy) return;
    // Capture stable values before any async gap
    final babyId = ref.read(currentBabyIdProvider);
    if (babyId == null) return;
    final eventId = widget.event.id;
    final eventStartAt = widget.event.startAt;

    // Disable button immediately to prevent double-tap
    setState(() => _busy = true);

    // Ask for ml while widget is still alive
    final ml = await _showMlDialog();
    if (!mounted) return;

    final now = DateTime.now();
    try {
      await ref.read(eventsRepositoryProvider).updateEvent(babyId, eventId, {
        'status': 'completed',
        'endAt': now,
        'durationSec': now.difference(eventStartAt).inSeconds,
        if (ml != null) 'metadata.bottleMl': ml,
      });
      // Widget will be removed by stream update — no setState needed on success
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, 'Error al finalizar: $e');
        setState(() => _busy = false);
      }
    }
  }

  Future<int?> _showMlDialog() {
    // Use closure variable instead of TextEditingController to avoid lifecycle issues
    String rawInput = '';
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cuántos ml tomó?'),
        content: TextField(
          keyboardType: TextInputType.number,
          autofocus: true,
          onChanged: (v) => rawInput = v,
          decoration: const InputDecoration(
            labelText: 'Cantidad (ml)',
            hintText: 'Ej: 120',
            suffixText: 'ml',
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(int.tryParse(rawInput.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Omitir'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(int.tryParse(rawInput.trim())),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishGeneric() async {
    if (_busy) return;
    setState(() => _busy = true);
    final babyId = ref.read(currentBabyIdProvider);
    if (babyId == null) { setState(() => _busy = false); return; }
    try {
      await ref.read(eventsRepositoryProvider).closeEvent(
        babyId, widget.event.id, DateTime.now());
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Error al finalizar: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final color = event.type.color;

    if (event.type == EventType.nursing) return _buildNursing(color);
    if (event.type == EventType.bottle) return _buildBottle(color);
    return _buildGeneric(event, color);
  }

  Widget _buildNursing(Color color) {
    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                PhosphorIcon(widget.event.type.icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Lactancia en curso',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SideCounter(
                  label: 'Izquierdo',
                  time: _fmtSec(_displayLeft),
                  active: _breast == 'left',
                  color: color,
                ),
                _SideCounter(
                  label: 'Derecho',
                  time: _fmtSec(_displayRight),
                  active: _breast == 'right',
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _switchSide,
                    icon: const PhosphorIcon(PhosphorIconsRegular.arrowsLeftRight, size: 16),
                    label: const Text('Cambiar lado'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _finishNursing,
                    icon: const PhosphorIcon(PhosphorIconsRegular.stop, size: 16),
                    label: const Text('Finalizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottle(Color color) {
    final elapsed = Duration(seconds: _totalElapsedSec);
    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            PhosphorIcon(widget.event.type.icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Biberón en curso',
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    AppDateUtils.formatCounter(elapsed),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _busy ? null : _finishBottle,
              icon: const PhosphorIcon(PhosphorIconsRegular.stop, size: 16),
              label: const Text('Finalizar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneric(BabyEvent event, Color color) {
    final elapsed = Duration(seconds: _totalElapsedSec);
    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            PhosphorIcon(event.type.icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.type.label,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    AppDateUtils.formatCounter(elapsed),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _busy ? null : _finishGeneric,
              icon: const PhosphorIcon(PhosphorIconsRegular.stop, size: 16),
              label: const Text('Finalizar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideCounter extends StatelessWidget {
  const _SideCounter({
    required this.label,
    required this.time,
    required this.active,
    required this.color,
  });

  final String label;
  final String time;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: active ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: active ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

