import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../baby/presentation/controllers/current_baby_provider.dart';
import '../../presentation/controllers/calendar_controller.dart';
import '../widgets/day_cell.dart';
import '../../../../features/home/presentation/controllers/home_controller.dart';
import '../../../../core/utils/date_utils.dart';

class CalendarModal extends ConsumerWidget {
  const CalendarModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baby = ref.watch(currentBabyProvider).valueOrNull;
    final activeDay = ref.watch(activeDayProvider);
    final eventCounts = ref.watch(calendarEventCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const PhosphorIcon(PhosphorIconsRegular.x),
        ),
      ),
      body: eventCounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (counts) => TableCalendar(
          firstDay: baby?.birthDate ?? DateTime(2020),
          lastDay: DateTime.now(),
          focusedDay: activeDay,
          selectedDayPredicate: (day) => isSameDay(day, activeDay),
          onDaySelected: (selectedDay, _) {
            ref.read(activeDayProvider.notifier).setDay(selectedDay);
            context.pop();
          },
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (ctx, day, _) {
              final key = AppDateUtils.toDayKey(day);
              final count = counts[key] ?? 0;
              return DayCell(
                day: day,
                eventCount: count,
                babyBirthDate: baby?.birthDate,
              );
            },
          ),
          headerStyle:
              const HeaderStyle(formatButtonVisible: false),
        ),
      ),
    );
  }
}
