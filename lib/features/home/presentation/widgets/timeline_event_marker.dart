import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../events/domain/models/baby_event.dart';
import '../../../../app/theme/app_colors.dart';

class TimelineEventMarker extends StatelessWidget {
  const TimelineEventMarker({
    super.key,
    required this.event,
    required this.xPos,
    this.onTap,
  });

  final BabyEvent event;
  final double xPos;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: xPos - 14,
      top: 18,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: event.type.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: event.type.color.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Center(
            child: PhosphorIcon(
              event.type.icon,
              size: 14,
              color: AppColors.onPrimaryLight,
            ),
          ),
        ),
      ),
    );
  }
}

