import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/daily_stats.dart';

final statsRepositoryProvider = Provider<StatsRepository>((ref) => StatsRepository());

class StatsRepository {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference _statsRef(String babyId) => _firestore
      .collection('babies')
      .doc(babyId)
      .collection('dailyStats');

  Future<List<DailyStats>> fetchRange(
    String babyId, {
    required String fromDay,
    required String toDay,
  }) async {
    final snap = await _statsRef(babyId)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: fromDay)
        .where(FieldPath.documentId, isLessThanOrEqualTo: toDay)
        .orderBy(FieldPath.documentId)
        .limit(31)
        .get();
    return snap.docs.map(DailyStats.fromFirestore).toList();
  }

  Stream<List<DailyStats>> watchRange(
    String babyId, {
    required String fromDay,
    required String toDay,
  }) {
    return _statsRef(babyId)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: fromDay)
        .where(FieldPath.documentId, isLessThanOrEqualTo: toDay)
        .orderBy(FieldPath.documentId)
        .limit(31)
        .snapshots()
        .map((snap) => snap.docs.map(DailyStats.fromFirestore).toList());
  }

  Stream<DailyStats?> watchDay(String babyId, String dayKey) {
    return _statsRef(babyId).doc(dayKey).snapshots().map(
        (doc) => doc.exists ? DailyStats.fromFirestore(doc) : null);
  }
}
