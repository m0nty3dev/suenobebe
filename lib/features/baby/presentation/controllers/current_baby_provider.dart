import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/baby.dart';
import '../../data/baby_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

// Use select so watchBaby is only re-subscribed when currentBabyId actually
// changes — not on every unrelated user doc update (e.g. fcmTokens).
final currentBabyProvider = StreamProvider<Baby?>((ref) {
  final babyId = ref.watch(
    appUserProvider.select((v) => v.valueOrNull?.currentBabyId),
  );
  if (babyId == null || babyId.isEmpty) return Stream.value(null);
  return ref.watch(babyRepositoryProvider).watchBaby(babyId);
});

final currentBabyIdProvider = Provider<String?>((ref) {
  return ref.watch(
    appUserProvider.select((v) => v.valueOrNull?.currentBabyId),
  );
});
