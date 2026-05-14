import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/usecases/predict_next_nap.dart';
import '../controllers/home_controller.dart';
import '../../../baby/presentation/controllers/current_baby_provider.dart';
import '../../../../core/utils/date_utils.dart';

// No StatefulWidget/Timer needed — the shared minuteTickProvider drives rebuilds.
class PredictedNapBanner extends ConsumerWidget {
  const PredictedNapBanner({super.key});

  String _fmtHHMM(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtCountdown(DateTime predicted, DateTime now) {
    final mins = predicted.difference(now).inMinutes;
    if (mins < 60) return 'en ${mins}min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? 'en ${h}h' : 'en ${h}h ${m}min';
  }

  String _fmtDuration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild once per minute.
    ref.watch(minuteTickProvider);

    final baby = ref.watch(currentBabyProvider).valueOrNull;
    final todayEvents = ref.watch(todayEventsProvider).valueOrNull ?? [];
    final historicalEvents = ref.watch(recentEventsProvider).valueOrNull ?? [];

    if (baby == null) return const SizedBox.shrink();

    final now = AppDateUtils.nowMadrid();
    final prediction = PredictNextNap()(
      baby: baby,
      todayEvents: todayEvents,
      historicalEvents: historicalEvents,
      now: now,
    );

    if (prediction == null) return const SizedBox.shrink();

    final norms = PredictNextNap.normsFor(baby);
    const color = AppColors.predictionColor;

    final elapsed = now.difference(prediction.wakeStartedAt);
    final total = Duration(minutes: prediction.wakeWindowMinutes);
    final progress = (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(PhosphorIconsFill.moon, size: 15, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Próxima siesta estimada',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fmtHHMM(prediction.predictedAt),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    _fmtCountdown(prediction.predictedAt, now),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color.withValues(alpha: 0.75),
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              color: color,
              backgroundColor: color.withValues(alpha: 0.18),
            ),
          ),
          // Age-based reference chips: expected naps + nap duration
          if (norms != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _InfoChip(
                  icon: PhosphorIconsRegular.moon,
                  label: '${norms.napsExpected} siesta${norms.napsExpected == 1 ? '' : 's'}/día',
                  color: color,
                ),
                _InfoChip(
                  icon: PhosphorIconsRegular.timer,
                  label: '~${_fmtDuration(norms.napDurationMinutes)}',
                  color: color,
                ),
              ],
            ),
          ],
          if (prediction.isPersonalized) ...[
            const SizedBox(height: 4),
            Text(
              'Basado en el historial de ${baby.name}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color.withValues(alpha: 0.60),
                    fontSize: 9,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 11, color: color.withValues(alpha: 0.80)),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color.withValues(alpha: 0.85),
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}
