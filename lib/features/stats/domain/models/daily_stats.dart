import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'daily_stats.freezed.dart';
part 'daily_stats.g.dart';

@freezed
class DailyStats with _$DailyStats {
  const factory DailyStats({
    required String date,
    @Default(0) int totalSleepDayMinutes,
    @Default(0) int totalSleepNightMinutes,
    @Default(0) int totalSleepMinutes,
    @Default(0) int napCount,
    @Default(0) int nightWakeCount,
    @Default(0) int feedingCount,
    @Default(0) int totalFeedingMinutes,
    @Default(0) int totalBottleMl,
    DateTime? morningWakeAt,
    DateTime? bedtimeAt,
    @Default(0) int eventsCount,
    DateTime? computedAt,
  }) = _DailyStats;

  factory DailyStats.fromJson(Map<String, dynamic> json) =>
      _$DailyStatsFromJson(json);

  factory DailyStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyStats(
      date: doc.id,
      totalSleepDayMinutes: data['totalSleepDayMinutes'] as int? ?? 0,
      totalSleepNightMinutes: data['totalSleepNightMinutes'] as int? ?? 0,
      totalSleepMinutes: data['totalSleepMinutes'] as int? ?? 0,
      napCount: data['napCount'] as int? ?? 0,
      nightWakeCount: data['nightWakeCount'] as int? ?? 0,
      feedingCount: data['feedingCount'] as int? ?? 0,
      totalFeedingMinutes: data['totalFeedingMinutes'] as int? ?? 0,
      totalBottleMl: data['totalBottleMl'] as int? ?? 0,
      morningWakeAt: (data['morningWakeAt'] as Timestamp?)?.toDate(),
      bedtimeAt: (data['bedtimeAt'] as Timestamp?)?.toDate(),
      eventsCount: data['eventsCount'] as int? ?? 0,
      computedAt: (data['computedAt'] as Timestamp?)?.toDate(),
    );
  }
}
