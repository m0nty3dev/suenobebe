import '../models/baby_event.dart';
import '../models/event_type.dart';
import '../../data/events_repository.dart';
import 'validate_no_overlap.dart';
import '../../../../core/services/analytics/analytics_service.dart';

class CreateEventException implements Exception {
  const CreateEventException(this.message, {this.conflictingEvent});
  final String message;
  final BabyEvent? conflictingEvent;
}

class CreateEvent {
  const CreateEvent(this._repository, this._validateNoOverlap);

  final EventsRepository _repository;
  final ValidateNoOverlap _validateNoOverlap;

  /// Creates a live (or instant) event via the server-side callable CF.
  /// The CF atomically closes any existing live event, sets trial.firstEventAt,
  /// and creates the event. No client-side overlap validation needed for live
  /// events because only one live event may exist at a time.
  Future<BabyEvent> callLive({
    required String babyId,
    required String userId,
    required EventType type,
    required String dayKey,
    DateTime? startAt, // defaults to now; may be in the past for backfill
    EventMetadata? metadata,
  }) async {
    final effectiveStart = startAt ?? DateTime.now();
    final event = BabyEvent(
      id: '',
      type: type,
      startAt: effectiveStart,
      endAt: type.isDuration ? null : effectiveStart,
      status: type.isDuration ? EventStatus.live : EventStatus.completed,
      metadata: metadata ?? const EventMetadata(),
      dayKey: dayKey,
      createdBy: userId,
      createdAt: effectiveStart,
      updatedAt: effectiveStart,
    );

    final result = await _repository.callCreate(babyId, event);
    AnalyticsService.logEventLogged(type.name, 'live');
    if (result.isFirstEvent) AnalyticsService.logTrialStarted();
    return event.copyWith(id: result.eventId);
  }

  Future<BabyEvent> callManual({
    required String babyId,
    required String userId,
    required EventType type,
    required DateTime startAt,
    DateTime? endAt,
    required String dayKey,
    int? bottleMl,
    String? breast,
    int? leftDurationSec,
    int? rightDurationSec,
    String? note,
  }) async {
    // For instant events, endAt = startAt (point in time)
    final effectiveEnd = endAt ?? startAt;

    // Client-side overlap validation for fast UX feedback (server also validates)
    final conflict = await _validateNoOverlap.call(
      babyId,
      start: startAt,
      end: effectiveEnd,
      dayKey: dayKey,
    );
    if (conflict != null) {
      throw CreateEventException(
        'Este horario se solapa con ${conflict.type.label}. Edítalo primero.',
        conflictingEvent: conflict,
      );
    }

    final now = DateTime.now();
    int? durationSec;
    if (effectiveEnd != startAt) {
      durationSec = effectiveEnd.difference(startAt).inSeconds;
    }

    final event = BabyEvent(
      id: '',
      type: type,
      startAt: startAt,
      endAt: effectiveEnd,
      durationSec: durationSec,
      status: EventStatus.completed,
      metadata: EventMetadata(
        bottleMl: bottleMl,
        breast: breast,
        leftDurationSec: leftDurationSec,
        rightDurationSec: rightDurationSec,
        note: note,
      ),
      dayKey: dayKey,
      createdBy: userId,
      createdAt: now,
      updatedAt: now,
    );

    final result = await _repository.callCreate(babyId, event);
    AnalyticsService.logEventLogged(type.name, 'manual');
    if (result.isFirstEvent) AnalyticsService.logTrialStarted();
    return event.copyWith(id: result.eventId);
  }
}
