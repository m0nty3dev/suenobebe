import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class AppDateUtils {
  static String toDayKey(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  static String formatCounter(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '$m min';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  static String formatTime(DateTime dt) => DateFormat('HH:mm').format(dt);

  static String formatDate(DateTime dt) =>
      DateFormat('EEEE, d \'de\' MMMM', 'es').format(dt);

  static String formatShortDate(DateTime dt) =>
      DateFormat('d MMM', 'es').format(dt);

  // Lazily initialized after tz.initializeTimeZones() in main().
  static final _madrid = tz.getLocation('Europe/Madrid');

  /// Current time in Europe/Madrid, regardless of device timezone.
  static DateTime nowMadrid() {
    try {
      final t = tz.TZDateTime.now(_madrid);
      return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second, t.millisecond);
    } catch (_) {
      return DateTime.now();
    }
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime startOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  static DateTime endOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, 23, 59, 59);
}
