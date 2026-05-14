import '../../../events/domain/models/baby_event.dart';
import '../../../events/domain/models/event_type.dart';

class CounterResult {
  const CounterResult({
    required this.sleepLabel,
    required this.sleepDuration,
    this.feedingLabel,
    this.feedingDuration,
  });

  final String sleepLabel;
  final Duration sleepDuration;
  final String? feedingLabel;
  final Duration? feedingDuration;
}

class ComputeCounters {
  CounterResult call({
    required List<BabyEvent> events,
    required DateTime now,
  }) {
    final sleepResult = _computeSleep(events, now);
    final feedingResult = _computeFeeding(events, now);

    return CounterResult(
      sleepLabel: sleepResult.$1,
      sleepDuration: sleepResult.$2,
      feedingLabel: feedingResult?.$1,
      feedingDuration: feedingResult?.$2,
    );
  }

  Duration _clamp(Duration d) =>
      d.isNegative ? Duration.zero : d;

  (String, Duration) _computeSleep(List<BabyEvent> events, DateTime now) {
    // Live nap → baby is sleeping right now
    final liveNap = events.where((e) => e.isLive && e.type == EventType.nap).toList();
    if (liveNap.isNotEmpty) {
      return ('Durmiendo hace', _clamp(now.difference(liveNap.first.startAt)));
    }

    // Live nightWake → baby is awake at night
    final liveNightWake =
        events.where((e) => e.isLive && e.type == EventType.nightWake).toList();
    if (liveNightWake.isNotEmpty) {
      return ('Despierto desde', _clamp(now.difference(liveNightWake.first.startAt)));
    }

    // Collect state-change points from completed/instant events.
    // Each entry is (timestamp, isSleeping).
    final changes = <(DateTime, bool)>[];

    for (final e in events) {
      switch (e.type) {
        case EventType.bedtime:
          // Instant event: baby went to sleep
          changes.add((e.startAt, true));
        case EventType.morningWake:
          // Instant event: baby woke up for the day
          changes.add((e.startAt, false));
        case EventType.nap:
          if (!e.isLive && e.endAt != null) {
            changes.add((e.startAt, true)); // nap started → sleeping
            changes.add((e.endAt!, false)); // nap ended → awake
          }
        case EventType.nightWake:
          if (!e.isLive && e.endAt != null) {
            changes.add((e.startAt, false)); // night wake started → awake
            changes.add((e.endAt!, true)); // night wake ended → back to sleep
          }
        default:
          break;
      }
    }

    if (changes.isEmpty) {
      return ('Sin registros aún', Duration.zero);
    }

    // Most recent state change wins
    changes.sort((a, b) => b.$1.compareTo(a.$1));
    final latest = changes.first;

    return latest.$2
        ? ('Durmiendo hace', _clamp(now.difference(latest.$1)))
        : ('Despierto hace', _clamp(now.difference(latest.$1)));
  }

  (String, Duration)? _computeFeeding(List<BabyEvent> events, DateTime now) {
    final feedings = events
        .where((e) => e.type.isFeedingRelated)
        .toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));

    if (feedings.isEmpty) return null;

    final last = feedings.first;
    if (last.isLive) {
      return ('Comiendo desde hace', _clamp(now.difference(last.startAt)));
    }
    return ('Última toma hace', _clamp(now.difference(last.startAt)));
  }
}
