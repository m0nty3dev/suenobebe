import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_type.dart';

part 'baby_event.freezed.dart';
part 'baby_event.g.dart';

enum EventStatus { live, completed }

@freezed
class EventMetadata with _$EventMetadata {
  const factory EventMetadata({
    String? breast,
    int? leftDurationSec,
    int? rightDurationSec,
    int? bottleMl,
    String? note,
  }) = _EventMetadata;

  factory EventMetadata.fromJson(Map<String, dynamic> json) =>
      _$EventMetadataFromJson(json);
}

@freezed
class BabyEvent with _$BabyEvent {
  const BabyEvent._();

  const factory BabyEvent({
    required String id,
    required EventType type,
    required DateTime startAt,
    DateTime? endAt,
    int? durationSec,
    @Default(EventStatus.completed) EventStatus status,
    @Default(EventMetadata()) EventMetadata metadata,
    required String dayKey,
    required String createdBy,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _BabyEvent;

  factory BabyEvent.fromJson(Map<String, dynamic> json) =>
      _$BabyEventFromJson(json);

  factory BabyEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BabyEvent(
      id: doc.id,
      type: EventType.fromFirestore(data['type'] as String),
      startAt: (data['startAt'] as Timestamp).toDate(),
      endAt: (data['endAt'] as Timestamp?)?.toDate(),
      durationSec: data['durationSec'] as int?,
      status: data['status'] == 'live' ? EventStatus.live : EventStatus.completed,
      metadata: data['metadata'] != null
          ? EventMetadata.fromJson(Map<String, dynamic>.from(data['metadata'] as Map))
          : const EventMetadata(),
      dayKey: data['dayKey'] as String,
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type.firestoreValue,
        'startAt': Timestamp.fromDate(startAt),
        'endAt': endAt != null ? Timestamp.fromDate(endAt!) : null,
        'durationSec': durationSec,
        'status': status.name,
        'metadata': metadata.toJson(),
        'dayKey': dayKey,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  bool get isLive => status == EventStatus.live;

  Duration get effectiveDuration {
    if (durationSec != null) return Duration(seconds: durationSec!);
    if (endAt != null) return endAt!.difference(startAt);
    return DateTime.now().difference(startAt);
  }
}
