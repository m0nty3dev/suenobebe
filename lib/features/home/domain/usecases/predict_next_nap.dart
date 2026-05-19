import '../../../baby/domain/models/baby.dart';
import '../../../events/domain/models/baby_event.dart';
import '../../../events/domain/models/event_type.dart';

class NapPrediction {
  final DateTime predictedAt;
  final DateTime wakeStartedAt;
  final int wakeWindowMinutes;
  final bool isPersonalized;

  const NapPrediction({
    required this.predictedAt,
    required this.wakeStartedAt,
    required this.wakeWindowMinutes,
    required this.isPersonalized,
  });
}

/// Age-based sleep norms derived from pediatric sleep research.
/// All values are typical ranges; historical data overrides when ≥5 days available.
class _AgeNorms {
  final int minAgeMonths;
  final int maxAgeMonths;

  /// Typical wake window in minutes (time awake before needing to sleep again).
  final int wakeWindowFirst;  // first wake of the day
  final int wakeWindowLater;  // subsequent wake windows

  /// Expected number of naps per day.
  final int napsExpected;

  /// Typical nap duration in minutes.
  final int napDurationMinutes;

  /// Typical total night sleep in minutes.
  final int nightSleepMinutes;

  const _AgeNorms({
    required this.minAgeMonths,
    required this.maxAgeMonths,
    required this.wakeWindowFirst,
    required this.wakeWindowLater,
    required this.napsExpected,
    required this.napDurationMinutes,
    required this.nightSleepMinutes,
  });

  /// Wake window for a given nap index (0-based).
  int wakeWindow(int napsDone) => napsDone == 0 ? wakeWindowFirst : wakeWindowLater;
}

/// Reference table indexed by age. All windows are in minutes.
/// Source: Weissbluth (2015), Mindell (2010), AASM paediatric guidelines.
const _ageTable = [
  _AgeNorms(minAgeMonths: 0,  maxAgeMonths: 1,  wakeWindowFirst: 45,  wakeWindowLater: 45,  napsExpected: 6, napDurationMinutes: 45,  nightSleepMinutes: 480),
  _AgeNorms(minAgeMonths: 2,  maxAgeMonths: 3,  wakeWindowFirst: 60,  wakeWindowLater: 75,  napsExpected: 4, napDurationMinutes: 60,  nightSleepMinutes: 510),
  _AgeNorms(minAgeMonths: 4,  maxAgeMonths: 5,  wakeWindowFirst: 90,  wakeWindowLater: 120, napsExpected: 3, napDurationMinutes: 75,  nightSleepMinutes: 540),
  _AgeNorms(minAgeMonths: 6,  maxAgeMonths: 8,  wakeWindowFirst: 150, wakeWindowLater: 180, napsExpected: 2, napDurationMinutes: 90,  nightSleepMinutes: 570),
  _AgeNorms(minAgeMonths: 9,  maxAgeMonths: 13, wakeWindowFirst: 210, wakeWindowLater: 240, napsExpected: 2, napDurationMinutes: 90,  nightSleepMinutes: 600),
  _AgeNorms(minAgeMonths: 14, maxAgeMonths: 17, wakeWindowFirst: 270, wakeWindowLater: 300, napsExpected: 1, napDurationMinutes: 90,  nightSleepMinutes: 660),
  _AgeNorms(minAgeMonths: 18, maxAgeMonths: 23, wakeWindowFirst: 300, wakeWindowLater: 330, napsExpected: 1, napDurationMinutes: 75,  nightSleepMinutes: 660),
  _AgeNorms(minAgeMonths: 24, maxAgeMonths: 35, wakeWindowFirst: 360, wakeWindowLater: 390, napsExpected: 1, napDurationMinutes: 60,  nightSleepMinutes: 660),
];

class PredictNextNap {
  NapPrediction? call({
    required Baby baby,
    required List<BabyEvent> todayEvents,
    required List<BabyEvent> historicalEvents,
    required DateTime now,
  }) {
    // No prediction while baby is sleeping
    final liveNap = todayEvents.where((e) =>
        e.isLive &&
        (e.type == EventType.nap ||
            e.type == EventType.nightWake ||
            e.type == EventType.bedtime)).firstOrNull;
    if (liveNap != null) return null;

    // Find last wake-up reference point today
    final sorted = [...todayEvents]..sort((a, b) => a.startAt.compareTo(b.startAt));
    DateTime? lastWakeTime;
    for (final e in sorted.reversed) {
      if (e.type == EventType.morningWake) {
        lastWakeTime = e.startAt;
        break;
      }
      if ((e.type == EventType.nap || e.type == EventType.nightWake) &&
          !e.isLive &&
          e.endAt != null) {
        lastWakeTime = e.endAt!;
        break;
      }
    }
    if (lastWakeTime == null) return null;

    final napsDone = sorted.where((e) => e.type == EventType.nap && !e.isLive).length;
    final ageMonths = _ageInMonths(baby.birthDate, now);
    final norms = _normsForAge(ageMonths);

    // If baby is too old for nap prediction (no norms), skip.
    if (norms == null) return null;

    // Try personalized wake window from historical data (≥5 distinct days).
    final personalized = _personalizedWakeWindow(historicalEvents);
    final wakeMinutes = personalized ?? norms.wakeWindow(napsDone);
    if (wakeMinutes <= 0) return null;

    // Skip prediction if baby already completed expected nap count for their age.
    if (napsDone >= norms.napsExpected && personalized == null) return null;

    final predicted = lastWakeTime.add(Duration(minutes: wakeMinutes));

    if (!predicted.isAfter(now)) return null;
    // Don't show if the prediction is more than 4 hours away.
    if (predicted.difference(now).inMinutes > 240) return null;

    return NapPrediction(
      predictedAt: predicted,
      wakeStartedAt: lastWakeTime,
      wakeWindowMinutes: wakeMinutes,
      isPersonalized: personalized != null,
    );
  }

  /// Returns age-appropriate norms for the given age in months, or null if
  /// the baby is too old to benefit from nap prediction (≥36 months).
  _AgeNorms? _normsForAge(int ageMonths) {
    for (final row in _ageTable) {
      if (ageMonths >= row.minAgeMonths && ageMonths <= row.maxAgeMonths) return row;
    }
    return null; // ≥36 months — no nap prediction
  }

  /// Returns age-appropriate nap count, nap duration, and night sleep
  /// reference values for display/informational purposes.
  static _AgeNorms? normsFor(Baby baby) {
    final now = DateTime.now();
    final birth = baby.birthDate;
    var months = (now.year - birth.year) * 12 + (now.month - birth.month);
    if (now.day < birth.day) months--;
    if (months < 0) months = 0;
    for (final row in _ageTable) {
      if (months >= row.minAgeMonths && months <= row.maxAgeMonths) return row;
    }
    return null;
  }

  /// Computes average wake window from historical nap events.
  /// Returns null if fewer than 5 days of data are available.
  int? _personalizedWakeWindow(List<BabyEvent> historical) {
    final dayGroups = <String, List<BabyEvent>>{};
    for (final e in historical) {
      dayGroups.putIfAbsent(e.dayKey, () => []).add(e);
    }
    if (dayGroups.length < 5) return null;

    final windows = <int>[];
    for (final dayEvents in dayGroups.values) {
      final sorted = [...dayEvents]..sort((a, b) => a.startAt.compareTo(b.startAt));
      DateTime? lastWake;
      for (final e in sorted) {
        if (e.type == EventType.morningWake) {
          lastWake = e.startAt;
        } else if ((e.type == EventType.nap || e.type == EventType.nightWake) &&
            !e.isLive && e.endAt != null) {
          if (lastWake != null) {
            final mins = e.startAt.difference(lastWake).inMinutes;
            if (mins > 20 && mins < 360) windows.add(mins);
          }
          lastWake = e.endAt;
        }
      }
    }
    if (windows.isEmpty) return null;
    return windows.reduce((a, b) => a + b) ~/ windows.length;
  }

  int _ageInMonths(DateTime birthDate, DateTime now) {
    var months = (now.year - birthDate.year) * 12 +
        (now.month - birthDate.month);
    if (now.day < birthDate.day) months--;
    return months < 0 ? 0 : months;
  }
}
