import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../domain/models/event_type.dart';
import '../../domain/models/baby_event.dart';
import '../../domain/usecases/create_event.dart';
import '../../data/events_repository.dart';
import '../../../baby/presentation/controllers/current_baby_provider.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/usecases/validate_no_overlap.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../app/theme/app_colors.dart';

class AddEventSheet extends ConsumerWidget {
  const AddEventSheet({super.key});

  List<EventType> _contextualOrder(List<BabyEvent> events) {
    final hasMorningWake = events.any((e) => e.type == EventType.morningWake);
    final hasBedtime = events.any((e) => e.type == EventType.bedtime);

    if (!hasMorningWake) {
      return [
        EventType.morningWake,
        EventType.nap,
        EventType.nursing,
        EventType.bottle,
        EventType.bedtime,
        EventType.nightWake,
      ];
    }
    if (hasMorningWake && !hasBedtime) {
      return [
        EventType.nap,
        EventType.nursing,
        EventType.bottle,
        EventType.morningWake,
        EventType.bedtime,
        EventType.nightWake,
      ];
    }
    return [
      EventType.nightWake,
      EventType.nursing,
      EventType.bottle,
      EventType.morningWake,
      EventType.nap,
      EventType.bedtime,
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(activeDayEventsProvider).valueOrNull ?? [];
    final activeDay = ref.watch(activeDayProvider);
    final isToday = AppDateUtils.isSameDay(activeDay, DateTime.now());
    final ordered = _contextualOrder(events);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Añadir evento',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.9,
                    children: ordered
                        .map((t) => _EventCard(
                              type: t,
                              onTap: () => _selectType(context, ref, t, isToday: isToday),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Do NOT pop AddEventSheet before showing mode sheet — pop it inside
  // the mode sheet callbacks so context and ref are still valid.
  void _selectType(BuildContext context, WidgetRef ref, EventType type, {required bool isToday}) {
    _showModeSheet(context, ref, type, isToday: isToday);
  }

  void _showModeSheet(BuildContext context, WidgetRef ref, EventType type, {required bool isToday}) {
    showModalBottomSheet(
      context: context,
      builder: (modeCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type.label,
                    style: Theme.of(modeCtx).textTheme.headlineSmall),
                const SizedBox(height: 24),
                // Live options only available for today
                if (isToday) ...[
                  // Nursing: show left/right breast buttons instead of generic "start"
                  if (type == EventType.nursing) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final router = GoRouter.of(modeCtx);
                              final messenger = ScaffoldMessenger.of(modeCtx);
                              Navigator.of(modeCtx).pop();
                              Navigator.of(context).pop();
                              _startNursingLive(ref, 'left', router, messenger);
                            },
                            icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft, size: 16),
                            label: const Text('Pecho\nizquierdo'),
                            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 56)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final router = GoRouter.of(modeCtx);
                              final messenger = ScaffoldMessenger.of(modeCtx);
                              Navigator.of(modeCtx).pop();
                              Navigator.of(context).pop();
                              _startNursingLive(ref, 'right', router, messenger);
                            },
                            icon: const PhosphorIcon(PhosphorIconsRegular.arrowRight, size: 16),
                            label: const Text('Pecho\nderecho'),
                            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 56)),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        final router = GoRouter.of(modeCtx);
                        final messenger = ScaffoldMessenger.of(modeCtx);
                        Navigator.of(modeCtx).pop();
                        Navigator.of(context).pop();
                        _startLive(ref, type, router, messenger);
                      },
                      icon: const PhosphorIcon(PhosphorIconsRegular.play),
                      label: Text(type.isDuration ? 'Iniciar ahora' : 'Ahora'),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52)),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: () {
                    final router = GoRouter.of(modeCtx);
                    Navigator.of(modeCtx).pop();
                    Navigator.of(context).pop();
                    router.push('/event/new',
                        extra: {'type': type.firestoreValue});
                  },
                  icon: const PhosphorIcon(PhosphorIconsRegular.pencil),
                  label: const Text('Introducir manualmente'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startNursingLive(
    WidgetRef ref,
    String breast,
    GoRouter router,
    ScaffoldMessengerState messenger,
  ) async {
    final babyId = ref.read(currentBabyIdProvider);
    final userId = ref.read(authStateProvider).valueOrNull?.uid;
    if (babyId == null || userId == null) return;

    final activeDay = ref.read(activeDayProvider);
    final dayKey = AppDateUtils.toDayKey(activeDay);

    try {
      final repo = ref.read(eventsRepositoryProvider);
      final validate = ValidateNoOverlap(repo);
      final useCase = CreateEvent(repo, validate);
      await useCase.callLive(
        babyId: babyId,
        userId: userId,
        type: EventType.nursing,
        dayKey: dayKey,
        metadata: EventMetadata(breast: breast, leftDurationSec: 0, rightDurationSec: 0),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.errorColor),
      );
    }
  }

  Future<void> _startLive(
    WidgetRef ref,
    EventType type,
    GoRouter router,
    ScaffoldMessengerState messenger,
  ) async {
    final babyId = ref.read(currentBabyIdProvider);
    final userId = ref.read(authStateProvider).valueOrNull?.uid;
    if (babyId == null || userId == null) return;

    final activeDay = ref.read(activeDayProvider);
    final dayKey = AppDateUtils.toDayKey(activeDay);

    try {
      final repo = ref.read(eventsRepositoryProvider);
      final validate = ValidateNoOverlap(repo);
      final useCase = CreateEvent(repo, validate);
      await useCase.callLive(
        babyId: babyId,
        userId: userId,
        type: type,
        dayKey: dayKey,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.errorColor),
      );
    }
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.type, required this.onTap});

  final EventType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: type.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: type.color.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(type.icon, color: type.color, size: 32),
            const SizedBox(height: 8),
            Text(
              type.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: type.color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

