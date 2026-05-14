import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

@freezed
class AppUser with _$AppUser {
  const AppUser._();

  const factory AppUser({
    required String id,
    required String email,
    required String displayName,
    String? photoUrl,
    String? caregiverAlias,
    @Default('es') String locale,
    String? currentBabyId,
    LegalAccepted? legalAccepted,
    @Default(false) bool deletionScheduled,
    DateTime? deletionScheduledAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    Map<String, dynamic>? legalAccepted;
    if (data['legalAccepted'] is Map) {
      final raw = Map<String, dynamic>.from(data['legalAccepted'] as Map);
      legalAccepted = {
        ...raw,
        'acceptedAt': raw['acceptedAt'] is Timestamp
            ? (raw['acceptedAt'] as Timestamp).toDate().toIso8601String()
            : raw['acceptedAt'],
      };
    }

    return AppUser.fromJson({
      'id': doc.id,
      ...data,
      'legalAccepted': legalAccepted,
      'createdAt': (data['createdAt'] as Timestamp?)?.toDate().toIso8601String() ??
          DateTime.now().toIso8601String(),
      'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate().toIso8601String() ??
          DateTime.now().toIso8601String(),
      'deletionScheduledAt':
          (data['deletionScheduledAt'] as Timestamp?)?.toDate().toIso8601String(),
    });
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    json['createdAt'] = Timestamp.fromDate(createdAt);
    json['updatedAt'] = Timestamp.fromDate(updatedAt);
    if (deletionScheduledAt != null) {
      json['deletionScheduledAt'] = Timestamp.fromDate(deletionScheduledAt!);
    }
    return json;
  }
}

@freezed
class LegalAccepted with _$LegalAccepted {
  const factory LegalAccepted({
    required int privacyVersion,
    required int termsVersion,
    required DateTime acceptedAt,
  }) = _LegalAccepted;

  factory LegalAccepted.fromJson(Map<String, dynamic> json) =>
      _$LegalAcceptedFromJson(json);
}
