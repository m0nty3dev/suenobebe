import 'package:flutter_test/flutter_test.dart';
import 'package:suenobebe/features/home/domain/usecases/compute_counters.dart';
import 'package:suenobebe/features/events/domain/models/baby_event.dart';
import 'package:suenobebe/features/events/domain/models/event_type.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

BabyEvent _event({
  required EventType type,
  required DateTime startAt,
  DateTime? endAt,
  EventStatus status = EventStatus.completed,
  String dayKey = '2024-01-15',
}) =>
    BabyEvent(
      id: '$type-${startAt.millisecondsSinceEpoch}',
      type: type,
      startAt: startAt,
      endAt: endAt,
      status: status,
      dayKey: dayKey,
      createdBy: 'uid',
      createdAt: startAt,
      updatedAt: startAt,
      metadata: const EventMetadata(),
    );

void main() {
  final counter = ComputeCounters();

  // ---------------------------------------------------------------------------
  // Basic same-day scenarios
  // ---------------------------------------------------------------------------

  group('ComputeCounters — same-day scenarios', () {
    test('no events → Sin registros', () {
      final result = counter(
        events: [],
        now: DateTime(2024, 1, 15, 10, 0),
      );
      expect(result.sleepLabel, 'Sin registros aún');
      expect(result.sleepDuration, Duration.zero);
    });

    test('live nap → Durmiendo hace', () {
      final napStart = DateTime(2024, 1, 15, 9, 0);
      final now = DateTime(2024, 1, 15, 10, 0);
      final result = counter(
        events: [
          _event(type: EventType.nap, startAt: napStart, status: EventStatus.live),
        ],
        now: now,
      );
      expect(result.sleepLabel, 'Durmiendo hace');
      expect(result.sleepDuration, const Duration(hours: 1));
    });

    test('completed nap → Despierto hace (desde endAt)', () {
      final napStart = DateTime(2024, 1, 15, 9, 0);
      final napEnd = DateTime(2024, 1, 15, 10, 0);
      final now = DateTime(2024, 1, 15, 11, 0);
      final result = counter(
        events: [
          _event(type: EventType.nap, startAt: napStart, endAt: napEnd),
        ],
        now: now,
      );
      expect(result.sleepLabel, 'Despierto hace');
      expect(result.sleepDuration, const Duration(hours: 1));
    });

    test('bedtime → Durmiendo hace', () {
      final bedtime = DateTime(2024, 1, 15, 21, 0);
      final now = DateTime(2024, 1, 15, 22, 30);
      final result = counter(
        events: [
          _event(type: EventType.bedtime, startAt: bedtime),
        ],
        now: now,
      );
      expect(result.sleepLabel, 'Durmiendo hace');
      expect(result.sleepDuration, const Duration(hours: 1, minutes: 30));
    });

    test('morningWake → Despierto hace', () {
      final wake = DateTime(2024, 1, 15, 8, 0);
      final now = DateTime(2024, 1, 15, 10, 0);
      final result = counter(
        events: [
          _event(type: EventType.morningWake, startAt: wake),
        ],
        now: now,
      );
      expect(result.sleepLabel, 'Despierto hace');
      expect(result.sleepDuration, const Duration(hours: 2));
    });

    test('live nightWake → Despierto desde', () {
      final wakeStart = DateTime(2024, 1, 16, 2, 0);
      final now = DateTime(2024, 1, 16, 2, 45);
      final result = counter(
        events: [
          _event(
              type: EventType.nightWake,
              startAt: wakeStart,
              status: EventStatus.live),
        ],
        now: now,
      );
      expect(result.sleepLabel, 'Despierto desde');
      expect(result.sleepDuration, const Duration(minutes: 45));
    });

    test('completed nightWake → back to sleeping', () {
      final bedtime = DateTime(2024, 1, 15, 21, 0);
      final wakeStart = DateTime(2024, 1, 16, 2, 0);
      final wakeEnd = DateTime(2024, 1, 16, 2, 30);
      final now = DateTime(2024, 1, 16, 3, 0);
      final result = counter(
        events: [
          _event(type: EventType.bedtime, startAt: bedtime),
          _event(type: EventType.nightWake, startAt: wakeStart, endAt: wakeEnd),
        ],
        now: now,
      );
      // After nightWake ends (02:30), baby is back to sleeping
      expect(result.sleepLabel, 'Durmiendo hace');
      expect(result.sleepDuration, const Duration(minutes: 30));
    });
  });

  // ---------------------------------------------------------------------------
  // Cross-day scenarios: bedtime on day D, counter queried on day D+1
  // ---------------------------------------------------------------------------

  group('ComputeCounters — cross-day night (N1 regression)', () {
    // This simulates the fix: CountersPanel now passes yesterday's events too.
    // If only today's events (D+1) are passed, the counter would show
    // "Sin registros" even though the baby is sleeping since last night's bedtime.

    test('bedtime D + now D+1 at 02:00 → Durmiendo hace (cross-day)', () {
      // Bedtime on Monday 21:30 (dayKey = 2024-01-15)
      final bedtime = DateTime(2024, 1, 15, 21, 30);
      // Now is Tuesday 02:00 (dayKey = 2024-01-16)
      final now = DateTime(2024, 1, 16, 2, 0);

      // With the fix: both days' events are passed.
      final result = counter(
        events: [
          _event(
              type: EventType.bedtime,
              startAt: bedtime,
              dayKey: '2024-01-15'), // yesterday
        ],
        now: now,
      );
      expect(result.sleepLabel, 'Durmiendo hace');
      // 02:00 - 21:30 = 4h30m
      expect(result.sleepDuration, const Duration(hours: 4, minutes: 30));
    });

    test('bedtime D + nightWake D+1 01:00-01:30 + now D+1 02:00 → Durmiendo 30 min', () {
      final bedtime = DateTime(2024, 1, 15, 21, 30);
      final wakeStart = DateTime(2024, 1, 16, 1, 0);
      final wakeEnd = DateTime(2024, 1, 16, 1, 30);
      final now = DateTime(2024, 1, 16, 2, 0);

      final result = counter(
        events: [
          _event(type: EventType.bedtime, startAt: bedtime, dayKey: '2024-01-15'),
          _event(type: EventType.nightWake, startAt: wakeStart, endAt: wakeEnd, dayKey: '2024-01-16'),
        ],
        now: now,
      );
      // Most recent state: nightWake ended at 01:30 → back to sleeping
      expect(result.sleepLabel, 'Durmiendo hace');
      expect(result.sleepDuration, const Duration(minutes: 30));
    });

    test('bedtime D + live nightWake D+1 at 01:30 + now 02:00 → Despierto desde', () {
      final bedtime = DateTime(2024, 1, 15, 21, 30);
      final wakeStart = DateTime(2024, 1, 16, 1, 30);
      final now = DateTime(2024, 1, 16, 2, 0);

      final result = counter(
        events: [
          _event(type: EventType.bedtime, startAt: bedtime, dayKey: '2024-01-15'),
          _event(
              type: EventType.nightWake,
              startAt: wakeStart,
              status: EventStatus.live,
              dayKey: '2024-01-16'),
        ],
        now: now,
      );
      expect(result.sleepLabel, 'Despierto desde');
      expect(result.sleepDuration, const Duration(minutes: 30));
    });

    test('bedtime D + morningWake D+1 08:40 + now D+1 09:00 → Despierto hace 20 min', () {
      final bedtime = DateTime(2024, 1, 15, 21, 30);
      final morningWake = DateTime(2024, 1, 16, 8, 40);
      final now = DateTime(2024, 1, 16, 9, 0);

      final result = counter(
        events: [
          _event(type: EventType.bedtime, startAt: bedtime, dayKey: '2024-01-15'),
          _event(type: EventType.morningWake, startAt: morningWake, dayKey: '2024-01-16'),
        ],
        now: now,
      );
      // morningWake is the most recent state change → awake
      expect(result.sleepLabel, 'Despierto hace');
      expect(result.sleepDuration, const Duration(minutes: 20));
    });

    test('if ONLY todayEvents passed (before fix), cross-day bedtime returns zero', () {
      // This documents the regression that the N1 fix resolves.
      // With only D+1 events (no bedtime), the counter returns "Sin registros".
      final now = DateTime(2024, 1, 16, 2, 0);
      final result = counter(
        events: [], // today D+1 has no events
        now: now,
      );
      expect(result.sleepLabel, 'Sin registros aún');
      expect(result.sleepDuration, Duration.zero);
    });
  });

  // ---------------------------------------------------------------------------
  // Age-boundary: duration never goes negative
  // ---------------------------------------------------------------------------

  group('ComputeCounters — clamp negative durations', () {
    test('state change in the future → duration is zero (not negative)', () {
      final futureTime = DateTime(2024, 1, 15, 12, 0);
      final now = DateTime(2024, 1, 15, 10, 0); // now is BEFORE the event

      final result = counter(
        events: [_event(type: EventType.morningWake, startAt: futureTime)],
        now: now,
      );
      // Duration should be clamped to zero, not negative.
      expect(result.sleepDuration, Duration.zero);
    });
  });

  // ---------------------------------------------------------------------------
  // Feeding counter
  // ---------------------------------------------------------------------------

  group('ComputeCounters — feeding counter', () {
    test('no feedings → feedingLabel is null', () {
      final result = counter(events: [], now: DateTime(2024, 1, 15, 10, 0));
      expect(result.feedingLabel, isNull);
    });

    test('completed nursing → Última toma hace X', () {
      final feed = DateTime(2024, 1, 15, 9, 0);
      final now = DateTime(2024, 1, 15, 10, 30);
      final result = counter(
        events: [_event(type: EventType.nursing, startAt: feed)],
        now: now,
      );
      expect(result.feedingLabel, 'Última toma hace');
      expect(result.feedingDuration, const Duration(hours: 1, minutes: 30));
    });

    test('live bottle → Comiendo desde hace X', () {
      final feed = DateTime(2024, 1, 15, 9, 0);
      final now = DateTime(2024, 1, 15, 9, 20);
      final result = counter(
        events: [
          _event(type: EventType.bottle, startAt: feed, status: EventStatus.live),
        ],
        now: now,
      );
      expect(result.feedingLabel, 'Comiendo desde hace');
      expect(result.feedingDuration, const Duration(minutes: 20));
    });

    test('picks most recent feeding when multiple exist', () {
      final older = DateTime(2024, 1, 15, 7, 0);
      final newer = DateTime(2024, 1, 15, 11, 0);
      final now = DateTime(2024, 1, 15, 12, 0);
      final result = counter(
        events: [
          _event(type: EventType.nursing, startAt: older),
          _event(type: EventType.bottle, startAt: newer),
        ],
        now: now,
      );
      expect(result.feedingDuration, const Duration(hours: 1));
    });
  });
}
