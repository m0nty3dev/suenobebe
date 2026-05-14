import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../controllers/home_controller.dart';
import '../widgets/timeline_bar.dart';
import '../widgets/counters_panel.dart';
import '../widgets/day_night_toggle.dart';
import '../widgets/predicted_nap_banner.dart';
import '../../../baby/presentation/controllers/current_baby_provider.dart';
import '../../../events/presentation/screens/add_event_sheet.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/services/ads/admob_banner.dart';
import '../../../events/domain/models/baby_event.dart';
import '../../../events/domain/models/event_type.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baby = ref.watch(currentBabyProvider).valueOrNull;
    final events = ref.watch(activeDayEventsProvider).valueOrNull ?? [];
    final prevEvents = ref.watch(prevActiveDayEventsProvider).valueOrNull ?? [];
    final dayMode = ref.watch(effectiveDayModeProvider);
    final activeDay = ref.watch(activeDayProvider);
    final canWrite = ref.watch(canWriteProvider);

    if (baby == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/calendar'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppDateUtils.formatDate(activeDay),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (!AppDateUtils.isSameDay(
                              activeDay, DateTime.now()))
                            TextButton(
                              onPressed: () =>
                                  ref.read(activeDayProvider.notifier).resetToday(),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                              ),
                              child: const Text('Volver a hoy'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  DayNightToggle(
                    mode: dayMode,
                    onToggle: () => ref
                        .read(forcedDayModeProvider.notifier)
                        .toggle(dayMode),
                  ),
                ],
              ),
            ),

            // Trial banner
            _TrialBanner(),

            // Counters
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: CountersPanel(),
            ),
            const SizedBox(height: 10),
            // Predicted next nap (only when relevant)
            const PredictedNapBanner(),
            const SizedBox(height: 10),
            // Timeline + live indicator + daily summary
            Expanded(
              child: Align(
                alignment: const Alignment(0, -0.25),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TimelineBar(
                          events: events,
                          previousDayEvents: prevEvents,
                          baby: baby,
                          dayMode: dayMode,
                          activeDay: activeDay,
                          onEventTap: (event) {
                            if (!canWrite) {
                              context.push('/paywall?source=event_block');
                              return;
                            }
                            context.push('/event/${event.id}?babyId=${baby.id}');
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DailySummaryPanel(events: events),
                    ],
                  ),
                ),
              ),
            ),

            // AdMob banner
            const AdmobBanner(),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (!canWrite) {
            context.push('/paywall?source=event_block');
            return;
          }
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const AddEventSheet(),
          );
        },
        child: const PhosphorIcon(PhosphorIconsRegular.plus),
      ),
    );
  }
}


class _TrialBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baby = ref.watch(currentBabyProvider).valueOrNull;
    if (baby == null) return const SizedBox.shrink();

    final sub = baby.subscription;
    final statusName = sub.status.name;

    String? bannerText;
    if (statusName == 'trial') {
      final remaining = baby.trial.expiresAt != null
          ? baby.trial.expiresAt!.difference(DateTime.now()).inDays + 1
          : 0;
      if (remaining > 0) bannerText = 'Trial: te quedan $remaining días';
    } else if (statusName == 'cancelled') {
      final remaining = sub.expiresAt != null
          ? sub.expiresAt!.difference(DateTime.now()).inDays + 1
          : 0;
      if (remaining > 0) {
        bannerText = 'Tu suscripción se cancela en $remaining días';
      }
    } else if (statusName == 'grace') {
      bannerText = 'Pago pendiente: regularízalo';
    }

    if (bannerText == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const PhosphorIcon(PhosphorIconsRegular.clock, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bannerText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/paywall?source=trial_expired'),
            child: Text(
              'Suscribirme',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ConsumerWidget: the shared minuteTickProvider drives rebuilds — no internal timer.
class _DailySummaryPanel extends ConsumerWidget {
  const _DailySummaryPanel({required this.events});
  final List<BabyEvent> events;

  Duration _totalSleep() {
    var total = Duration.zero;
    final now = DateTime.now().toLocal();
    for (final e in events) {
      if (e.type == EventType.nap || e.type == EventType.nightWake) {
        if (e.isLive) {
          total += now.difference(e.startAt);
        } else if (e.durationSec != null) {
          total += Duration(seconds: e.durationSec!);
        }
      }
    }
    return total;
  }

  int _feedingCount() => events
      .where((e) => e.type == EventType.nursing || e.type == EventType.bottle)
      .length;

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild once per minute so live-event durations stay current.
    ref.watch(minuteTickProvider);

    final sleep = _totalSleep();
    final feedings = _feedingCount();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              icon: PhosphorIconsRegular.moon,
              label: 'Sueño hoy',
              value: sleep == Duration.zero ? '—' : _formatDuration(sleep),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              icon: PhosphorIconsRegular.baby,
              label: 'Tomas hoy',
              value: feedings == 0 ? '—' : '$feedings',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          PhosphorIcon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

