import 'date_utils.dart';

/// Calcula el dayKey para un evento según la regla §3.3:
/// Los eventos durante la franja noche pertenecen al día que la noche empezó.
String computeDayKey({
  required DateTime eventTime,
  required String? currentBedtimeDayKey,
  required DateTime? currentBedtimeAt,
}) {
  if (currentBedtimeAt != null && currentBedtimeDayKey != null) {
    if (eventTime.isAfter(currentBedtimeAt)) {
      return currentBedtimeDayKey;
    }
  }
  // Madrugada (antes de las 6:00) asumimos que pertenece al día anterior
  if (eventTime.hour < 6) {
    return AppDateUtils.toDayKey(eventTime.subtract(const Duration(days: 1)));
  }
  return AppDateUtils.toDayKey(eventTime);
}
