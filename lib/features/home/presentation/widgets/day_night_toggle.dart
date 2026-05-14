import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../domain/usecases/compute_day_mode.dart';

class DayNightToggle extends StatelessWidget {
  const DayNightToggle({
    super.key,
    required this.mode,
    required this.onToggle,
  });

  final DayMode mode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isDay = mode == DayMode.day;
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              isDay ? PhosphorIconsFill.sun : PhosphorIconsRegular.sun,
              size: 18,
              color: isDay
                  ? const Color(0xFFE6B473)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            PhosphorIcon(
              !isDay ? PhosphorIconsFill.moon : PhosphorIconsRegular.moon,
              size: 18,
              color: !isDay
                  ? const Color(0xFF8FB4D9)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

