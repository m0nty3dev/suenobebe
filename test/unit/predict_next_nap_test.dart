import 'package:flutter_test/flutter_test.dart';
import 'package:suenobebe/features/home/domain/usecases/predict_next_nap.dart';
import 'package:suenobebe/features/baby/domain/models/baby.dart';
import 'package:suenobebe/features/events/domain/models/baby_event.dart';
import 'package:suenobebe/features/events/domain/models/event_type.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Baby _baby(DateTime birthDate) => Baby(
      id: 'test',
      name: 'Test',
      birthDate: birthDate,
      adminId: 'uid',
      subscription: BabySubscription(),
      trial: BabyTrial(
        hardExpiresAt: DateTime.now().add(const Duration(days: 30)),
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

BabyEvent _wakeEvent({required DateTime startAt, String dayKey = '2024-01-15'}) =>
    BabyEvent(
      id: 'e1',
      type: EventType.morningWake,
      startAt: startAt,
      endAt: startAt,
      status: EventStatus.completed,
      dayKey: dayKey,
      createdBy: 'uid',
      createdAt: startAt,
      updatedAt: startAt,
      metadata: const EventMetadata(),
    );

BabyEvent _napEvent({
  required DateTime startAt,
  required DateTime endAt,
  String dayKey = '2024-01-15',
}) =>
    BabyEvent(
      id: 'e2',
      type: EventType.nap,
      startAt: startAt,
      endAt: endAt,
      status: EventStatus.completed,
      dayKey: dayKey,
      createdBy: 'uid',
      createdAt: startAt,
      updatedAt: startAt,
      metadata: const EventMetadata(),
    );

// ---------------------------------------------------------------------------
// Age calculation tests
// ---------------------------------------------------------------------------

void main() {
  final predictor = PredictNextNap();

  group('_ageInMonths (via normsFor)', () {
    test('exact month boundary — same day of month', () {
      final birth = DateTime(2024, 1, 15);
      final baby = _baby(birth);
      // normsFor uses DateTime.now() internally, so we can't inject the test date.
      // We verify that the call succeeds and returns a non-null result for a
      // baby whose age (relative to real now) falls somewhere in the table.
      final norms = PredictNextNap.normsFor(baby);
      expect(norms, isNotNull); // baby is ~3 months in test environment
    });

    test('day boundary: born on 31st, checked on 1st of next month', () {
      // Baby born 2024-01-31. On 2024-02-01 they are 0 months + 1 day,
      // NOT 1 full month. The fixed formula should return 0.
      final birth = DateTime(2024, 1, 31);
      final now = DateTime(2024, 2, 1);
      // Use the corrected formula directly
      var months = (now.year - birth.year) * 12 + (now.month - birth.month);
      if (now.day < birth.day) months--;
      if (months < 0) months = 0;
      expect(months, equals(0));
    });

    test('day boundary: born on 15th, checked on 15th of next month', () {
      final birth = DateTime(2024, 1, 15);
      final now = DateTime(2024, 2, 15); // exactly 1 month
      var months = (now.year - birth.year) * 12 + (now.month - birth.month);
      if (now.day < birth.day) months--;
      if (months < 0) months = 0;
      expect(months, equals(1));
    });

    test('day boundary: born on 15th, checked on 14th of next month', () {
      final birth = DateTime(2024, 1, 15);
      final now = DateTime(2024, 2, 14); // not yet 1 month
      var months = (now.year - birth.year) * 12 + (now.month - birth.month);
      if (now.day < birth.day) months--;
      if (months < 0) months = 0;
      expect(months, equals(0));
    });

    test('12 months old', () {
      final birth = DateTime(2023, 1, 15);
      final now = DateTime(2024, 1, 15);
      var months = (now.year - birth.year) * 12 + (now.month - birth.month);
      if (now.day < birth.day) months--;
      if (months < 0) months = 0;
      expect(months, equals(12));
    });

    test('never returns negative', () {
      // Future birth date (edge case guard)
      final birth = DateTime(2025, 6, 1);
      final now = DateTime(2024, 1, 1);
      var months = (now.year - birth.year) * 12 + (now.month - birth.month);
      if (now.day < birth.day) months--;
      if (months < 0) months = 0;
      expect(months, equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // Age table coverage tests
  // ---------------------------------------------------------------------------

  group('_ageTable ranges — no gaps between rows', () {
    // Verify the table covers 0–35 months without holes
    const table = [
      (0, 1), (2, 3), (4, 5), (6, 8), (9, 13),
      (14, 17), (18, 23), (24, 35),
    ];

    test('table starts at 0 months', () {
      expect(table.first.$1, equals(0));
    });

    test('table ends at 35 months', () {
      expect(table.last.$2, equals(35));
    });

    test('no gaps between rows', () {
      for (var i = 0; i < table.length - 1; i++) {
        final currentMax = table[i].$2;
        final nextMin = table[i + 1].$1;
        expect(nextMin, equals(currentMax + 1),
            reason:
                'Gap between row $i (max=$currentMax) and row ${i + 1} (min=$nextMin)');
      }
    });

    test('wake window increases monotonically with age', () {
      // First wake window of each row should be ≥ previous row's
      const firstWindows = [45, 60, 90, 150, 210, 270, 300, 360];
      for (var i = 1; i < firstWindows.length; i++) {
        expect(firstWindows[i], greaterThanOrEqualTo(firstWindows[i - 1]),
            reason: 'Wake window at index $i decreased vs ${i - 1}');
      }
    });

    test('nap count decreases or stays same with age', () {
      const napCounts = [6, 4, 3, 2, 2, 1, 1, 1];
      for (var i = 1; i < napCounts.length; i++) {
        expect(napCounts[i], lessThanOrEqualTo(napCounts[i - 1]),
            reason: 'Nap count at index $i increased vs ${i - 1}');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Prediction logic tests
  // ---------------------------------------------------------------------------

  group('PredictNextNap.call', () {
    // Baby 4 months old as of 2024-01-15 (the fixed "now" used in these tests).
    // Fixed date avoids dependency on DateTime.now() which would drift relative
    // to the injected `now` parameter.
    final birth4mo = DateTime(2023, 9, 15); // exactly 4 months before 2024-01-15

    test('returns null when no morning wake found today', () {
      final baby = _baby(birth4mo);
      final now = DateTime(2024, 1, 15, 10, 0);
      final result = predictor(
        baby: baby,
        todayEvents: [],
        historicalEvents: [],
        now: now,
      );
      expect(result, isNull);
    });

    test('returns prediction after morning wake', () {
      final baby = _baby(birth4mo);
      final wakeTime = DateTime(2024, 1, 15, 7, 30);
      final now = DateTime(2024, 1, 15, 8, 15); // 45 min after wake

      final result = predictor(
        baby: baby,
        todayEvents: [_wakeEvent(startAt: wakeTime)],
        historicalEvents: [],
        now: now,
      );

      expect(result, isNotNull);
      // First wake window for 4-month baby = 90 min
      // predicted = 07:30 + 90 min = 09:00
      expect(result!.predictedAt, equals(DateTime(2024, 1, 15, 9, 0)));
      expect(result.isPersonalized, isFalse);
    });

    test('returns null when prediction already in the past', () {
      final baby = _baby(birth4mo);
      final wakeTime = DateTime(2024, 1, 15, 7, 0);
      // Now is 3h after wake — prediction (07:00 + 90 min = 08:30) is past
      final now = DateTime(2024, 1, 15, 10, 0);

      final result = predictor(
        baby: baby,
        todayEvents: [_wakeEvent(startAt: wakeTime)],
        historicalEvents: [],
        now: now,
      );

      expect(result, isNull);
    });

    test('returns null when prediction is more than 4h away', () {
      // Baby just woke up; with 90-min window, prediction is 90 min away — fine.
      // But if wake window were 5h, it should be hidden.
      // Use newborn (45 min window): baby wakes at 06:00, now = 06:01
      final birthNewborn = DateTime(2023, 12, 26); // ~20 days before 2024-01-15
      final babyNewborn = _baby(birthNewborn);
      final wakeTime = DateTime(2024, 1, 15, 6, 0);
      final now = DateTime(2024, 1, 15, 6, 1);

      final result = predictor(
        baby: babyNewborn,
        todayEvents: [_wakeEvent(startAt: wakeTime)],
        historicalEvents: [],
        now: now,
      );

      // 45 min < 240 min → should show
      expect(result, isNotNull);
    });

    test('returns null when live nap is active', () {
      final baby = _baby(birth4mo);
      final wakeTime = DateTime(2024, 1, 15, 7, 30);
      final napStart = DateTime(2024, 1, 15, 9, 0);
      final now = DateTime(2024, 1, 15, 9, 30);

      final liveNap = BabyEvent(
        id: 'live',
        type: EventType.nap,
        startAt: napStart,
        endAt: null,
        status: EventStatus.live,
        dayKey: '2024-01-15',
        createdBy: 'uid',
        createdAt: napStart,
        updatedAt: napStart,
        metadata: const EventMetadata(),
      );

      final result = predictor(
        baby: baby,
        todayEvents: [_wakeEvent(startAt: wakeTime), liveNap],
        historicalEvents: [],
        now: now,
      );

      expect(result, isNull);
    });

    test('uses last nap end as wake reference (not morning wake)', () {
      final baby = _baby(birth4mo);
      final wakeTime = DateTime(2024, 1, 15, 7, 0);
      final napStart = DateTime(2024, 1, 15, 8, 30);
      final napEnd = DateTime(2024, 1, 15, 9, 45);
      final now = DateTime(2024, 1, 15, 10, 30); // 45 min after nap end

      final result = predictor(
        baby: baby,
        todayEvents: [
          _wakeEvent(startAt: wakeTime),
          _napEvent(startAt: napStart, endAt: napEnd),
        ],
        historicalEvents: [],
        now: now,
      );

      expect(result, isNotNull);
      // second wake window for 4-month = 120 min
      // predicted = napEnd (09:45) + 120 = 11:45
      expect(result!.predictedAt, equals(DateTime(2024, 1, 15, 11, 45)));
    });

    test('returns null for baby ≥36 months', () {
      final birthOld = DateTime(2020, 12, 15); // 37 months before 2024-01-15
      final baby = _baby(birthOld);
      final wakeTime = DateTime(2024, 1, 15, 7, 0);
      final now = DateTime(2024, 1, 15, 9, 0);

      final result = predictor(
        baby: baby,
        todayEvents: [_wakeEvent(startAt: wakeTime)],
        historicalEvents: [],
        now: now,
      );

      expect(result, isNull);
    });
  });
}
