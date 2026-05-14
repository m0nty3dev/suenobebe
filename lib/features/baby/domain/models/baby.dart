import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'baby.freezed.dart';
part 'baby.g.dart';

enum BabySex { male, female, other }

enum SubscriptionStatus {
  none,
  trial,
  trialExpired,
  active,
  grace,
  onHold,
  cancelled,
  expired,
}

enum SubscriptionPlan { monthly, annual }

@freezed
class Baby with _$Baby {
  const Baby._();

  const factory Baby({
    required String id,
    required String name,
    required DateTime birthDate,
    @Default(BabySex.other) BabySex sex,
    String? photoUrl,
    @Default([]) List<String> caregivers,
    required String adminId,
    @Default({}) Map<String, CaregiverInfo> caregiversInfo,
    required BabySubscription subscription,
    required BabyTrial trial,
    @Default('08:00') String estimatedMorningWake,
    @Default('22:00') String estimatedBedtime,
    DateTime? estimatesRecomputedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletionScheduledAt,
  }) = _Baby;

  factory Baby.fromJson(Map<String, dynamic> json) => _$BabyFromJson(json);

  static Map<String, dynamic> _normalizeTimestamps(Map<String, dynamic> map) {
    return map.map((key, value) {
      if (value is Timestamp) return MapEntry(key, value.toDate().toIso8601String());
      if (value is Map) return MapEntry(key, _normalizeTimestamps(Map<String, dynamic>.from(value)));
      return MapEntry(key, value);
    });
  }

  factory Baby.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Baby(
      id: doc.id,
      name: data['name'] as String,
      birthDate: (data['birthDate'] as Timestamp).toDate(),
      sex: BabySex.values.firstWhere(
        (e) => e.name == data['sex'],
        orElse: () => BabySex.other,
      ),
      photoUrl: data['photoUrl'] as String?,
      caregivers: List<String>.from(data['caregivers'] ?? []),
      adminId: data['adminId'] as String,
      caregiversInfo: (data['caregiversInfo'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, CaregiverInfo.fromJson(_normalizeTimestamps(Map<String, dynamic>.from(v as Map)))),
      ),
      subscription: BabySubscription.fromJson(
        _normalizeTimestamps(Map<String, dynamic>.from(data['subscription'] as Map? ?? {})),
      ),
      trial: BabyTrial.fromJson(
        _normalizeTimestamps(Map<String, dynamic>.from(data['trial'] as Map? ?? {})),
      ),
      estimatedMorningWake: data['estimatedMorningWake'] as String? ?? '08:00',
      estimatedBedtime: data['estimatedBedtime'] as String? ?? '22:00',
      estimatesRecomputedAt:
          (data['estimatesRecomputedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deletionScheduledAt: (data['deletionScheduledAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'birthDate': Timestamp.fromDate(birthDate),
      'sex': sex.name,
      'photoUrl': photoUrl,
      'caregivers': caregivers,
      'adminId': adminId,
      'caregiversInfo': caregiversInfo.map((k, v) => MapEntry(k, v.toJson())),
      'subscription': subscription.toJson(),
      'trial': trial.toJson(),
      'estimatedMorningWake': estimatedMorningWake,
      'estimatedBedtime': estimatedBedtime,
      'estimatesRecomputedAt': estimatesRecomputedAt != null
          ? Timestamp.fromDate(estimatesRecomputedAt!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'deletionScheduledAt': deletionScheduledAt != null
          ? Timestamp.fromDate(deletionScheduledAt!)
          : null,
    };
  }
}

@freezed
class CaregiverInfo with _$CaregiverInfo {
  const factory CaregiverInfo({
    required String alias,
    required String role,
    required DateTime joinedAt,
  }) = _CaregiverInfo;

  factory CaregiverInfo.fromJson(Map<String, dynamic> json) =>
      _$CaregiverInfoFromJson(json);
}

@freezed
class BabySubscription with _$BabySubscription {
  const factory BabySubscription({
    @Default(SubscriptionStatus.none) SubscriptionStatus status,
    SubscriptionPlan? plan,
    String? purchaseToken,
    String? productId,
    DateTime? expiresAt,
    @Default(false) bool autoRenew,
    DateTime? lastVerifiedAt,
  }) = _BabySubscription;

  factory BabySubscription.fromJson(Map<String, dynamic> json) =>
      _$BabySubscriptionFromJson(json);
}

@freezed
class BabyTrial with _$BabyTrial {
  const factory BabyTrial({
    DateTime? firstEventAt,
    DateTime? expiresAt,
    required DateTime hardExpiresAt,
  }) = _BabyTrial;

  factory BabyTrial.fromJson(Map<String, dynamic> json) =>
      _$BabyTrialFromJson(json);
}
