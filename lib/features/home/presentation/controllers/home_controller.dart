import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../baby/presentation/controllers/current_baby_provider.dart';
import '../../../events/data/events_repository.dart';
import '../../../events/domain/models/baby_event.dart';
import '../../domain/usecases/compute_day_mode.dart';
import '../../../../core/utils/date_utils.dart';

class ActiveDay extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now().toLocal();

  void setDay(DateTime day) => state = day.toLocal();
  void resetToday() => state = DateTime.now().toLocal();
}

final activeDayProvider = NotifierProvider<ActiveDay, DateTime>(ActiveDay.new);

// Shared 1-minute clock. autoDispose so the timer stops when no widget watches it
// (e.g., when the app is backgrounded and all tabs are hidden).
final minuteTickProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  controller.add(DateTime.now());
  final timer = Timer.periodic(const Duration(minutes: 1), (_) {
    if (!controller.isClosed) controller.add(DateTime.now());
  });
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

// Today's events — counters and prediction always reflect today
// even when the user is browsing a past day on the timeline.
final todayEventsProvider = StreamProvider.autoDispose<List<BabyEvent>>((ref) {
  final baby = ref.watch(currentBabyProvider).valueOrNull;
  if (baby == null) return Stream.value([]);
  final todayKey = AppDateUtils.toDayKey(AppDateUtils.nowMadrid());
  return ref.watch(eventsRepositoryProvider).watchEventsForDay(baby.id, todayKey);
});

// Yesterday's events — needed by the sleep counter at night after midnight.
// Bedtime lives in yesterday's dayKey; without this the counter shows
// "Sin registros" even while the baby is sleeping.
final prevTodayEventsProvider = StreamProvider.autoDispose<List<BabyEvent>>((ref) {
  final baby = ref.watch(currentBabyProvider).valueOrNull;
  if (baby == null) return Stream.value([]);
  final yesterday = AppDateUtils.nowMadrid().subtract(const Duration(days: 1));
  final dayKey = AppDateUtils.toDayKey(yesterday);
  return ref.watch(eventsRepositoryProvider).watchEventsForDay(baby.id, dayKey);
});

// Last 14 days of events for personalized nap prediction.
final recentEventsProvider = StreamProvider.autoDispose<List<BabyEvent>>((ref) {
  final baby = ref.watch(currentBabyProvider).valueOrNull;
  if (baby == null) return Stream.value([]);
  final now = AppDateUtils.nowMadrid();
  final from = now.subtract(const Duration(days: 14));
  return ref.watch(eventsRepositoryProvider).watchEventsForRange(baby.id, from, now);
});

final activeDayEventsProvider = StreamProvider.autoDispose<List<BabyEvent>>((ref) {
  final baby = ref.watch(currentBabyProvider).valueOrNull;
  if (baby == null) return Stream.value([]);

  final activeDay = ref.watch(activeDayProvider);
  final dayKey = AppDateUtils.toDayKey(activeDay);

  return ref.watch(eventsRepositoryProvider).watchEventsForDay(baby.id, dayKey);
});

// Events for the day BEFORE the active day — needed by the night timeline
// to find the bedtime event when it's early morning (before morningWake).
final prevActiveDayEventsProvider = StreamProvider.autoDispose<List<BabyEvent>>((ref) {
  final baby = ref.watch(currentBabyProvider).valueOrNull;
  if (baby == null) return Stream.value([]);

  final prevDay = ref.watch(activeDayProvider).subtract(const Duration(days: 1));
  final dayKey = AppDateUtils.toDayKey(prevDay);

  return ref.watch(eventsRepositoryProvider).watchEventsForDay(baby.id, dayKey);
});

// Events for the day AFTER the active day — needed by the night timeline
// (evening mode) to display the actual morningWake time of the next day
// when viewing a historical night.
final nextActiveDayEventsProvider = StreamProvider.autoDispose<List<BabyEvent>>((ref) {
  final baby = ref.watch(currentBabyProvider).valueOrNull;
  if (baby == null) return Stream.value([]);

  final nextDay = ref.watch(activeDayProvider).add(const Duration(days: 1));
  final dayKey = AppDateUtils.toDayKey(nextDay);

  return ref.watch(eventsRepositoryProvider).watchEventsForDay(baby.id, dayKey);
});

final liveEventProvider = StreamProvider.autoDispose<BabyEvent?>((ref) {
  final baby = ref.watch(currentBabyProvider).valueOrNull;
  if (baby == null) return Stream.value(null);
  return ref.watch(eventsRepositoryProvider).watchLiveEvent(baby.id);
});

final computedDayModeProvider = Provider.autoDispose<DayMode>((ref) {
  final baby = ref.watch(currentBabyProvider).valueOrNull;
  // Always use today's events for mode computation (not the active-day view).
  final events = ref.watch(todayEventsProvider).valueOrNull ?? [];
  if (baby == null) return DayMode.day;
  return ComputeDayMode()(
    baby: baby,
    todayEvents: events,
    now: DateTime.now().toLocal(),
  );
});

class ForcedDayMode extends Notifier<DayMode?> {
  @override
  DayMode? build() => null;

  void toggle(DayMode current) {
    state = current == DayMode.day ? DayMode.night : DayMode.day;
  }

  void clearForce() => state = null;
}

final forcedDayModeProvider = NotifierProvider<ForcedDayMode, DayMode?>(ForcedDayMode.new);

final effectiveDayModeProvider = Provider.autoDispose<DayMode>((ref) {
  final forced = ref.watch(forcedDayModeProvider);
  if (forced != null) return forced;
  return ref.watch(computedDayModeProvider);
});
