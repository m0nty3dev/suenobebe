import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/baby.dart';
import '../../../core/services/analytics/analytics_service.dart';

final babyRepositoryProvider = Provider<BabyRepository>((ref) => BabyRepository());

class BabyRepository {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference get _babies => _firestore.collection('babies');

  Future<Baby> createBaby({
    required String name,
    required DateTime birthDate,
    required BabySex sex,
    required String adminId,
    String? photoUrl,
  }) async {
    final now = DateTime.now();
    final data = {
      'name': name,
      'birthDate': Timestamp.fromDate(birthDate),
      'sex': sex.name,
      'photoUrl': photoUrl,
      'caregivers': [adminId],
      'adminId': adminId,
      'caregiversInfo': {
        adminId: {
          'alias': 'Cuidador',
          'role': 'admin',
          'joinedAt': Timestamp.fromDate(now),
        }
      },
      'subscription': {
        'status': 'none',
        'plan': null,
        'purchaseToken': null,
        'productId': null,
        'expiresAt': null,
        'autoRenew': false,
        'lastVerifiedAt': null,
      },
      'trial': {
        'firstEventAt': null,
        'expiresAt': null,
        'hardExpiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
      },
      'estimatedMorningWake': '08:00',
      'estimatedBedtime': '22:00',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    final ref = await _babies.add(data);
    final doc = await ref.get();
    AnalyticsService.logBabyCreated();
    return Baby.fromFirestore(doc);
  }

  Future<Baby?> fetchBaby(String babyId) async {
    final doc = await _babies.doc(babyId).get();
    if (!doc.exists) return null;
    return Baby.fromFirestore(doc);
  }

  Stream<Baby?> watchBaby(String babyId) {
    return _babies
        .doc(babyId)
        .snapshots()
        .map((doc) => doc.exists ? Baby.fromFirestore(doc) : null);
  }

  Future<void> updateBaby(String babyId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _babies.doc(babyId).update(data);
  }

  Future<void> setCaregiverAlias(
    String babyId,
    String userId,
    String alias,
  ) async {
    await _babies.doc(babyId).update({
      'caregiversInfo.$userId.alias': alias,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
