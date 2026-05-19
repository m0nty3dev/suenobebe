import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/baby_event.dart';
import '../../../core/config/constants.dart';

final eventsRepositoryProvider = Provider<EventsRepository>((ref) => EventsRepository());

class EventsRepository {
  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: AppConstants.firebaseRegion);

  CollectionReference _eventsRef(String babyId) =>
      _firestore.collection('babies').doc(babyId).collection('events');

  Stream<List<BabyEvent>> watchEventsForDay(String babyId, String dayKey) {
    return _eventsRef(babyId)
        .where('dayKey', isEqualTo: dayKey)
        .orderBy('startAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) {
              try {
                return BabyEvent.fromFirestore(doc);
              } catch (_) {
                return null;
              }
            })
            .whereType<BabyEvent>()
            .toList());
  }

  Stream<BabyEvent?> watchLiveEvent(String babyId) {
    return _eventsRef(babyId)
        .where('status', isEqualTo: 'live')
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          try {
            return BabyEvent.fromFirestore(snap.docs.first);
          } catch (_) {
            return null;
          }
        });
  }

  Future<List<BabyEvent>> fetchEventsForDay(String babyId, String dayKey) async {
    final snap = await _eventsRef(babyId)
        .where('dayKey', isEqualTo: dayKey)
        .orderBy('startAt')
        .get();
    return snap.docs
        .map((doc) {
          try {
            return BabyEvent.fromFirestore(doc);
          } catch (_) {
            return null;
          }
        })
        .whereType<BabyEvent>()
        .toList();
  }

  Stream<List<BabyEvent>> watchEventsForRange(
    String babyId,
    DateTime from,
    DateTime to,
  ) {
    return _eventsRef(babyId)
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('startAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) {
              try {
                return BabyEvent.fromFirestore(doc);
              } catch (_) {
                return null;
              }
            })
            .whereType<BabyEvent>()
            .toList());
  }

  Future<List<BabyEvent>> fetchEventsForRange(
    String babyId,
    DateTime from,
    DateTime to,
  ) async {
    final snap = await _eventsRef(babyId)
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('startAt')
        .get();
    return snap.docs
        .map((doc) {
          try {
            return BabyEvent.fromFirestore(doc);
          } catch (_) {
            return null;
          }
        })
        .whereType<BabyEvent>()
        .toList();
  }

  Future<BabyEvent> createEvent(String babyId, BabyEvent event) async {
    final ref = _eventsRef(babyId).doc();
    final data = event.copyWith(id: ref.id).toFirestore();
    await ref.set(data);
    final doc = await ref.get();
    return BabyEvent.fromFirestore(doc);
  }

  /// Creates an event via the createEventCallable Cloud Function.
  /// The CF atomically: verifies caregiver membership, closes any existing
  /// live event, validates no-overlap (completed events), sets trial.firstEventAt.
  /// Returns the created eventId and whether this was the first event ever.
  Future<({String eventId, bool isFirstEvent})> callCreate(
    String babyId,
    BabyEvent event,
  ) async {
    final callable = _functions.httpsCallable('createEventCallable');
    final result = await callable.call({
      'babyId': babyId,
      'type': event.type.firestoreValue,
      'startAt': event.startAt.millisecondsSinceEpoch,
      'endAt': event.endAt?.millisecondsSinceEpoch,
      'durationSec': event.durationSec,
      'status': event.status == EventStatus.live ? 'live' : 'completed',
      'dayKey': event.dayKey,
      'metadata': {
        'breast': event.metadata.breast,
        'leftDurationSec': event.metadata.leftDurationSec,
        'rightDurationSec': event.metadata.rightDurationSec,
        'bottleMl': event.metadata.bottleMl,
        'note': event.metadata.note,
      },
    });
    final data = result.data as Map<String, dynamic>;
    return (
      eventId: data['eventId'] as String,
      isFirstEvent: (data['isFirstEvent'] as bool?) ?? false,
    );
  }

  /// Writes `trial.firstEventAt = now` if it is not already set.
  /// Returns true if this was the first event (field was previously null).
  Future<bool> setFirstEventAtIfEmpty(String babyId) async {
    final babyRef = _firestore.collection('babies').doc(babyId);

    // Fast-path: read from Firestore offline cache (currentBabyProvider keeps
    // the doc cached). Avoids the full read-write transaction on every
    // subsequent event creation once firstEventAt is already set.
    try {
      final cached = await babyRef.get(const GetOptions(source: Source.cache));
      if (cached.exists) {
        final trial = cached.data()?['trial'] as Map<String, dynamic>?;
        if (trial?['firstEventAt'] != null) return false;
      }
    } catch (_) {
      // Cache miss — fall through to transaction.
    }

    bool wasEmpty = false;
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(babyRef);
      final trial = snap.data()?['trial'] as Map<String, dynamic>?;
      if (trial?['firstEventAt'] == null) {
        tx.update(babyRef, {
          'trial.firstEventAt': FieldValue.serverTimestamp(),
        });
        wasEmpty = true;
      }
    });
    return wasEmpty;
  }

  Future<void> updateEvent(
    String babyId,
    String eventId,
    Map<String, dynamic> data,
  ) async {
    final converted = <String, dynamic>{};
    for (final entry in data.entries) {
      converted[entry.key] =
          entry.value is DateTime ? Timestamp.fromDate(entry.value as DateTime) : entry.value;
    }
    converted['updatedAt'] = FieldValue.serverTimestamp();
    await _eventsRef(babyId).doc(eventId).update(converted);
  }

  /// Closes a live event atomically. Uses a transaction to prevent race
  /// conditions when two caregivers close the same event simultaneously.
  Future<void> closeEvent(String babyId, String eventId, DateTime endAt) async {
    final docRef = _eventsRef(babyId).doc(eventId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      final startAt =
          (snap.data() as Map<String, dynamic>)['startAt'] as Timestamp;
      final durationSec =
          endAt.difference(startAt.toDate()).inSeconds;
      tx.update(docRef, {
        'status': 'completed',
        'endAt': Timestamp.fromDate(endAt),
        'durationSec': durationSec,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<BabyEvent?> fetchEvent(String babyId, String eventId) async {
    try {
      final doc =
          await _eventsRef(babyId).doc(eventId).get();
      if (!doc.exists) return null;
      return BabyEvent.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteEvent(String babyId, String eventId) async {
    final callable = _functions.httpsCallable('deleteEventCallable');
    await callable.call({'babyId': babyId, 'eventId': eventId});
  }

  Future<BabyEvent?> fetchLiveEvent(String babyId) async {
    final snap = await _eventsRef(babyId)
        .where('status', isEqualTo: 'live')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    try {
      return BabyEvent.fromFirestore(snap.docs.first);
    } catch (_) {
      // Stale live event with unrecognized type — force-close it.
      await _eventsRef(babyId).doc(snap.docs.first.id).update({
        'status': 'completed',
        'endAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    }
  }

  Future<List<BabyEvent>> fetchEventsOnDay(String babyId, String dayKey) =>
      fetchEventsForDay(babyId, dayKey);

  Future<List<BabyEvent>> fetchOverlappingEvents(
    String babyId, {
    required DateTime start,
    required DateTime? end,
    String? excludeEventId,
    String? dayKey,
  }) async {
    final endQuery = end ?? DateTime.now();
    var query = _eventsRef(babyId)
        .where('startAt', isLessThan: Timestamp.fromDate(endQuery));
    if (dayKey != null) {
      query = query.where('dayKey', isEqualTo: dayKey);
    }
    // Limit prevents a full collection scan; 50 is well above any realistic
    // same-day event count, so legitimate overlaps are never missed.
    final snap = await query.limit(50).get();
    final events = snap.docs
        .map((doc) {
          try {
            return BabyEvent.fromFirestore(doc);
          } catch (_) {
            return null;
          }
        })
        .whereType<BabyEvent>()
        .toList();
    return events.where((e) {
      if (e.id == excludeEventId) return false;
      final eEnd = e.endAt ?? DateTime.now();
      return e.startAt.isBefore(endQuery) && eEnd.isAfter(start);
    }).toList();
  }

  Stream<List<BabyEvent>> watchRecentFeedings(String babyId, String dayKey) {
    return _eventsRef(babyId)
        .where('dayKey', isEqualTo: dayKey)
        .where('type', whereIn: ['nursing', 'bottle'])
        .orderBy('startAt', descending: true)
        .limit(5)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) {
              try {
                return BabyEvent.fromFirestore(doc);
              } catch (_) {
                return null;
              }
            })
            .whereType<BabyEvent>()
            .toList());
  }
}
