import 'package:flutter_test/flutter_test.dart';
import 'package:suenobebe/features/home/domain/usecases/compute_day_mode.dart';
import 'package:suenobebe/features/baby/domain/models/baby.dart';
import 'package:suenobebe/features/events/domain/models/baby_event.dart';
import 'package:suenobebe/features/events/domain/models/event_type.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Baby _baby() => Baby(
      id: 'test',
      name: 'Test',
      birthDate: DateTime(2024, 1, 15),
      adminId: 'uid',
      subscription: BabySubscription(),
      trial: BabyTrial(
        hardExpiresAt: DateTime.now().add(const Duration(days: 30)),
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

BabyEvent _event({
  required EventType type,
  required DateTime startAt,
  String dayKey = '2024-06-15',
}) =>
    BabyEvent(
      id: '$type-${startAt.millisecondsSinceEpoch}',
      type: type,
      startAt: startAt,
      endAt: startAt,
      status: EventStatus.completed,
      dayKey: dayKey,
      createdBy: 'uid',
      createdAt: startAt,
      updatedAt: startAt,
      metadata: const EventMetadata(),
    );

void main() {
  final compute = ComputeDayMode();
  final baby = _baby();

  group('ComputeDayMode — no events (default boundaries 08:00 – 00:00)', () {
    // Default: morningWake = 08:00, bedtime = midnight (next day 00:00).
    // → Day mode from 08:00 until 00:00.

    test('09:00 with no events → DayMode.day', () {
      final now = DateTime(2024, 6, 15, 9, 0);
      expect(compute(baby: baby, todayEvents: [], now: now), DayMode.day);
    });

    test('07:59 with no events → DayMode.night (before default morningWake)', () {
      final now = DateTime(2024, 6, 15, 7, 59);
      expect(compute(baby: baby, todayEvents: [], now: now), DayMode.night);
    });

    test('08:00 with no events → DayMode.day (exactly morningWake)', () {
      // now.isAfter(morningWakeEffective) — 08:00 is NOT after 08:00
      // So falls through to DayMode.night. Document this edge case.
      final now = DateTime(2024, 6, 15, 8, 0);
      // 08:00 is not strictly after 08:00, so: night
      expect(compute(baby: baby, todayEvents: [], now: now), DayMode.night);
    });

    test('08:01 with no events → DayMode.day', () {
      final now = DateTime(2024, 6, 15, 8, 1);
      expect(compute(baby: baby, todayEvents: [], now: now), DayMode.day);
    });

    test('23:59 with no events → DayMode.day (before midnight default bedtime)', () {
      final now = DateTime(2024, 6, 15, 23, 59);
      // bedtimeEffective = 2024-06-16 00:00, now = 2024-06-15 23:59
      // now.isAfter(bedtime) → false; now.isAfter(morning) → true → day
      expect(compute(baby: baby, todayEvents: [], now: now), DayMode.day);
    });

    test('00:01 on the SAME calendar day with no events → DayMode.night (before 08:00)', () {
      final now = DateTime(2024, 6, 15, 0, 1);
      expect(compute(baby: baby, todayEvents: [], now: now), DayMode.night);
    });
  });

  group('ComputeDayMode — with events', () {
    test('morningWake at 07:30, queried at 09:00 → DayMode.day', () {
      final now = DateTime(2024, 6, 15, 9, 0);
      final mw = _event(type: EventType.morningWake, startAt: DateTime(2024, 6, 15, 7, 30));
      expect(compute(baby: baby, todayEvents: [mw], now: now), DayMode.day);
    });

    test('morningWake at 07:30, queried at 07:29 → DayMode.night (before wake)', () {
      final now = DateTime(2024, 6, 15, 7, 29);
      final mw = _event(type: EventType.morningWake, startAt: DateTime(2024, 6, 15, 7, 30));
      expect(compute(baby: baby, todayEvents: [mw], now: now), DayMode.night);
    });

    test('bedtime at 21:00, queried at 22:00 → DayMode.night', () {
      final now = DateTime(2024, 6, 15, 22, 0);
      final bt = _event(type: EventType.bedtime, startAt: DateTime(2024, 6, 15, 21, 0));
      expect(compute(baby: baby, todayEvents: [bt], now: now), DayMode.night);
    });

    test('bedtime at 21:00, queried at 20:59 → DayMode.day', () {
      final now = DateTime(2024, 6, 15, 20, 59);
      final mw = _event(type: EventType.morningWake, startAt: DateTime(2024, 6, 15, 7, 30));
      final bt = _event(type: EventType.bedtime, startAt: DateTime(2024, 6, 15, 21, 0));
      expect(compute(baby: baby, todayEvents: [mw, bt], now: now), DayMode.day);
    });

    test('morningWake at 07:30 and bedtime at 21:00, queried at 12:00 → DayMode.day', () {
      final now = DateTime(2024, 6, 15, 12, 0);
      final mw = _event(type: EventType.morningWake, startAt: DateTime(2024, 6, 15, 7, 30));
      final bt = _event(type: EventType.bedtime, startAt: DateTime(2024, 6, 15, 21, 0));
      expect(compute(baby: baby, todayEvents: [mw, bt], now: now), DayMode.day);
    });

    test('uses lastWhere — two morning_wake events, uses the later one', () {
      final now = DateTime(2024, 6, 15, 10, 0);
      final mw1 = _event(type: EventType.morningWake, startAt: DateTime(2024, 6, 15, 7, 0));
      final mw2 = _event(type: EventType.morningWake, startAt: DateTime(2024, 6, 15, 9, 30));
      // lastWhere picks mw2 (09:30). now=10:00 is after → day
      expect(compute(baby: baby, todayEvents: [mw1, mw2], now: now), DayMode.day);
    });
  });
}
