import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/constants.dart';
import '../../../../core/services/analytics/analytics_service.dart';

final invitationsRepositoryProvider =
    Provider<InvitationsRepository>((ref) => InvitationsRepository());

class InvitationsRepository {
  final _functions = FirebaseFunctions.instanceFor(
      region: AppConstants.firebaseRegion);

  Future<String> createInvitation(String babyId) async {
    final result = await _functions
        .httpsCallable('createInvitation')
        .call({'babyId': babyId});
    AnalyticsService.logCaregiverInvited();
    return result.data['code'] as String;
  }

  Future<void> acceptInvitation(String code, String alias) async {
    await _functions
        .httpsCallable('acceptInvitation')
        .call({'code': code, 'alias': alias});
    AnalyticsService.logCaregiverJoined();
  }
}
