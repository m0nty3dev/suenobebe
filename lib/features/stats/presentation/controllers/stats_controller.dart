import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/stats_repository.dart';
import '../../domain/models/daily_stats.dart';
import '../../../baby/presentation/controllers/current_baby_provider.dart';
import '../../../../core/utils/date_utils.dart';

enum StatsRange { today, week, month }

class StatsRangeNotifier extends Notifier<StatsRange> {
  @override
  StatsRange build() => StatsRange.week;
  void set(StatsRange r) => state = r;
}

final statsRangeNotifierProvider =
    NotifierProvider<StatsRangeNotifier, StatsRange>(StatsRangeNotifier.new);

final statsDataProvider = StreamProvider.autoDispose<List<DailyStats>>((ref) {
  final baby = ref.watch(currentBabyProvider).valueOrNull;
  if (baby == null) return Stream.value([]);

  final range = ref.watch(statsRangeNotifierProvider);
  final days = range == StatsRange.today
      ? 1
      : range == StatsRange.week
          ? 7
          : 30;

  final now = AppDateUtils.nowMadrid();
  final todayKey = AppDateUtils.toDayKey(now);
  final fromDay =
      AppDateUtils.toDayKey(now.subtract(Duration(days: days - 1)));

  return ref
      .watch(statsRepositoryProvider)
      .watchRange(baby.id, fromDay: fromDay, toDay: todayKey);
});
