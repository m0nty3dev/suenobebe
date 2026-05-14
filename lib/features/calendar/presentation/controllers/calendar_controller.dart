import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../baby/presentation/controllers/current_baby_provider.dart';
import '../../../stats/data/stats_repository.dart';
import '../../../../core/utils/date_utils.dart';

// Uses dailyStats (1 doc/day) instead of raw events (N docs/day).
// This reduces Firestore reads by ~30x when opening the calendar.
final calendarEventCountsProvider =
    StreamProvider.autoDispose<Map<String, int>>((ref) {
  final baby = ref.watch(currentBabyProvider).valueOrNull;
  if (baby == null) return Stream.value({});

  final now = AppDateUtils.nowMadrid();
  final fromDay =
      AppDateUtils.toDayKey(now.subtract(const Duration(days: 60)));
  final toDay = AppDateUtils.toDayKey(now);

  return ref
      .watch(statsRepositoryProvider)
      .watchRange(baby.id, fromDay: fromDay, toDay: toDay)
      .map((statsList) {
    final counts = <String, int>{};
    for (final s in statsList) {
      counts[s.date] = s.eventsCount;
    }
    return counts;
  });
});
