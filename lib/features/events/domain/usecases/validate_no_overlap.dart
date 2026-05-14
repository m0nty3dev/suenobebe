import '../models/baby_event.dart';
import '../../data/events_repository.dart';

class ValidateNoOverlap {
  const ValidateNoOverlap(this._repository);

  final EventsRepository _repository;

  /// Returns the conflicting event if there is an overlap, null if clear.
  Future<BabyEvent?> call(
    String babyId, {
    required DateTime start,
    required DateTime? end,
    String? excludeEventId,
    String? dayKey,
  }) async {
    final overlapping = await _repository.fetchOverlappingEvents(
      babyId,
      start: start,
      end: end,
      excludeEventId: excludeEventId,
      dayKey: dayKey,
    );
    return overlapping.isEmpty ? null : overlapping.first;
  }
}
