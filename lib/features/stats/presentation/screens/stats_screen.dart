import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/stats_controller.dart';
import '../../domain/models/daily_stats.dart';
import '../widgets/stat_card.dart';
import '../../../../core/services/ads/admob_banner.dart';
import '../../../../app/theme/app_colors.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(statsRangeNotifierProvider);
    final data = ref.watch(statsDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<StatsRange>(
              segments: const [
                ButtonSegment(value: StatsRange.today, label: Text('Hoy')),
                ButtonSegment(value: StatsRange.week, label: Text('7 días')),
                ButtonSegment(value: StatsRange.month, label: Text('30 días')),
              ],
              selected: {range},
              onSelectionChanged: (s) =>
                  ref.read(statsRangeNotifierProvider.notifier).set(s.first),
            ),
          ),
          Expanded(
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (stats) => _StatsBody(stats: stats, range: range),
            ),
          ),
          const AdmobBanner(),
        ],
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats, required this.range});

  final List<DailyStats> stats;
  final StatsRange range;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Center(child: Text('Sin datos todavía'));
    }

    final totalSleep = stats.fold<int>(0, (s, d) => s + d.totalSleepMinutes);
    final totalNightSleep = stats.fold<int>(0, (s, d) => s + d.totalSleepNightMinutes);
    final totalDaySleep = stats.fold<int>(0, (s, d) => s + d.totalSleepDayMinutes);
    final avgSleep = stats.isNotEmpty ? totalSleep ~/ stats.length : 0;
    final totalFeedings = stats.fold<int>(0, (s, d) => s + d.feedingCount);
    final totalNightWakes = stats.fold<int>(0, (s, d) => s + d.nightWakeCount);

    String _fmt(int mins) => '${mins ~/ 60}h ${mins % 60}m';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Night / day sleep breakdown
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Sueño nocturno',
                value: _fmt(totalNightSleep),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Siestas',
                value: _fmt(totalDaySleep),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Total + average
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Sueño total',
                value: _fmt(totalSleep),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Media diaria',
                value: _fmt(avgSleep),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Tomas totales',
                value: '$totalFeedings',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Despertares nocturnos',
                value: '$totalNightWakes',
              ),
            ),
          ],
        ),

        // Charts (only when more than 1 day)
        if (stats.length > 1) ...[
          const SizedBox(height: 28),
          _StatChart(
            title: 'Sueño por día',
            unit: 'h',
            stats: stats,
            toValue: (s) => s.totalSleepMinutes / 60.0,
            color: AppColors.napColor,
            yLabelFn: (v) => '${v.toInt()}h',
            yInterval: 2,
          ),
          const SizedBox(height: 24),
          _StatChart(
            title: 'Tomas por día',
            unit: '',
            stats: stats,
            toValue: (s) => s.feedingCount.toDouble(),
            color: AppColors.nursingColor,
            yLabelFn: (v) => '${v.toInt()}',
            yInterval: null,
          ),
          const SizedBox(height: 24),
          _StatChart(
            title: 'Despertares nocturnos',
            unit: '',
            stats: stats,
            toValue: (s) => s.nightWakeCount.toDouble(),
            color: AppColors.nightWakeColor,
            yLabelFn: (v) => '${v.toInt()}',
            yInterval: null,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _StatChart extends StatelessWidget {
  const _StatChart({
    required this.title,
    required this.unit,
    required this.stats,
    required this.toValue,
    required this.color,
    required this.yLabelFn,
    this.yInterval,
  });

  final String title;
  final String unit;
  final List<DailyStats> stats;
  final double Function(DailyStats) toValue;
  final Color color;
  final String Function(double) yLabelFn;
  final double? yInterval;

  static const _weekdayAbbrevs = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  String _xLabel(int index) {
    if (index < 0 || index >= stats.length) return '';
    try {
      final date = DateTime.parse(stats[index].date);
      if (stats.length <= 7) {
        return _weekdayAbbrevs[date.weekday - 1];
      }
      // For 30 days: show label every 7 bars to avoid crowding
      if (index % 7 == 0 || index == stats.length - 1) {
        return '${date.day}/${date.month}';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final values = stats.map(toValue).toList();
    final rawMax = values.isEmpty ? 1.0 : values.reduce(math.max);

    // Compute a clean maxY with headroom
    double maxY;
    double interval;
    if (yInterval != null) {
      // Sleep chart: round up to nearest multiple of 2, add 2
      maxY = ((rawMax / 2).ceil() * 2 + 2).clamp(4.0, 24.0).toDouble();
      interval = yInterval!;
    } else {
      // Count chart: integer max + 2, min 4
      maxY = (rawMax.ceil() + 2).clamp(4.0, double.infinity).toDouble();
      interval = (maxY / 4).ceilToDouble().clamp(1.0, double.infinity);
    }

    final axisColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25);
    final labelStyle = TextStyle(
      fontSize: 10,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              barGroups: values.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value,
                      color: color,
                      width: stats.length <= 7 ? 16 : 8,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final label = _xLabel(value.toInt());
                      if (label.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(label, style: labelStyle),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Text(yLabelFn(value),
                          style: labelStyle,
                          textAlign: TextAlign.right);
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: axisColor, width: 1),
                  left: BorderSide(color: axisColor, width: 1),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: axisColor,
                  strokeWidth: 0.5,
                  dashArray: [4, 4],
                ),
              ),
              barTouchData: BarTouchData(enabled: false),
            ),
          ),
        ),
      ],
    );
  }
}

