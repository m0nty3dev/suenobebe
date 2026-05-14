import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';

class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.day,
    required this.eventCount,
    this.babyBirthDate,
  });

  final DateTime day;
  final int eventCount;
  final DateTime? babyBirthDate;

  Color _dotColor(BuildContext context) {
    final birth = babyBirthDate;
    if (birth != null &&
        day.isBefore(AppDateUtils.startOfDay(birth))) {
      return AppColors.calendarGrey;
    }
    if (day.isAfter(DateTime.now())) return AppColors.calendarGrey;
    if (eventCount >= 3) return AppColors.calendarGreen;
    if (eventCount >= 1) return AppColors.calendarOrange;
    return AppColors.calendarRed;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${day.day}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 2),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _dotColor(context),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
