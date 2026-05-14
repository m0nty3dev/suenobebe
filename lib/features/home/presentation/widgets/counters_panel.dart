import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/compute_counters.dart';
import '../controllers/home_controller.dart';
import '../../../../core/utils/date_utils.dart';

// ConsumerWidget (no StatefulWidget): the minute-tick provider drives rebuilds,
// so no manual Timer is needed here.
class CountersPanel extends ConsumerWidget {
  const CountersPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild once per minute.
    ref.watch(minuteTickProvider);

    final events = ref.watch(todayEventsProvider).valueOrNull ?? [];
    final result = ComputeCounters()(
      events: events,
      now: AppDateUtils.nowMadrid(),
    );

    return Row(
      children: [
        Expanded(
          child: _CounterCard(
            label: result.sleepLabel,
            value: result.sleepDuration == Duration.zero
                ? ''
                : AppDateUtils.formatCounter(result.sleepDuration),
            emptyText: result.sleepLabel,
          ),
        ),
        if (result.feedingLabel != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _CounterCard(
              label: result.feedingLabel!,
              value: AppDateUtils.formatCounter(result.feedingDuration!),
            ),
          ),
        ],
      ],
    );
  }
}

class _CounterCard extends StatelessWidget {
  const _CounterCard({
    required this.label,
    required this.value,
    this.emptyText,
  });

  final String label;
  final String value;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value.isEmpty ? (emptyText ?? '—') : value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
