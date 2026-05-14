import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/baby_event.dart';
import '../../data/events_repository.dart';
import 'validate_no_overlap.dart';
import 'create_event.dart';

class EditEvent {
  const EditEvent(this._repository, this._validateNoOverlap);

  final EventsRepository _repository;
  final ValidateNoOverlap _validateNoOverlap;

  Future<void> call({
    required String babyId,
    required String eventId,
    required DateTime startAt,
    DateTime? endAt,
    int? bottleMl,
    String? breast,
    int? leftDurationSec,
    int? rightDurationSec,
    String? note,
  }) async {
    final conflict = await _validateNoOverlap.call(
      babyId,
      start: startAt,
      end: endAt,
      excludeEventId: eventId,
    );
    if (conflict != null) {
      throw CreateEventException(
        'Este horario se solapa con ${conflict.type.label}. Edítalo primero.',
        conflictingEvent: conflict,
      );
    }

    int? durationSec;
    if (endAt != null) {
      durationSec = endAt.difference(startAt).inSeconds;
    }

    await _repository.updateEvent(babyId, eventId, {
      'startAt': Timestamp.fromDate(startAt),
      'endAt': endAt != null ? Timestamp.fromDate(endAt) : null,
      'durationSec': durationSec,
      'metadata.bottleMl': bottleMl,
      'metadata.breast': breast,
      'metadata.leftDurationSec': leftDurationSec,
      'metadata.rightDurationSec': rightDurationSec,
      'metadata.note': note,
    });
  }
}
