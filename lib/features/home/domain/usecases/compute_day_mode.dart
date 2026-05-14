import '../../../baby/domain/models/baby.dart';
import '../../../events/domain/models/event_type.dart';
import '../../../events/domain/models/baby_event.dart';

enum DayMode { day, night }

class ComputeDayMode {
  DayMode call({
    required Baby baby,
    required List<BabyEvent> todayEvents,
    required DateTime now,
  }) {
    final bedtime = _findEvent(todayEvents, EventType.bedtime);
    final morningWake = _findEvent(todayEvents, EventType.morningWake);

    // Default without data: day 08:00 → 00:00 (midnight), night 00:00 → 08:00.
    final morningWakeEffective = morningWake?.startAt ??
        DateTime(now.year, now.month, now.day, 8, 0);
    final bedtimeEffective = bedtime?.startAt ??
        DateTime(now.year, now.month, now.day + 1, 0, 0); // midnight

    if (now.isAfter(bedtimeEffective)) return DayMode.night;
    if (now.isAfter(morningWakeEffective) && now.isBefore(bedtimeEffective)) {
      return DayMode.day;
    }
    return DayMode.night;
  }

  BabyEvent? _findEvent(List<BabyEvent> events, EventType type) {
    try {
      return events.lastWhere((e) => e.type == type);
    } catch (_) {
      return null;
    }
  }
}
