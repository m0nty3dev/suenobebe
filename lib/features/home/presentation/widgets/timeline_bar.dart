import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../events/domain/models/baby_event.dart';
import '../../../events/domain/models/event_type.dart';
import '../../../baby/domain/models/baby.dart';
import '../../domain/usecases/compute_day_mode.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';

class TimelineBar extends StatefulWidget {
  const TimelineBar({
    super.key,
    required this.events,
    required this.baby,
    required this.dayMode,
    required this.activeDay,
    this.previousDayEvents = const [],
    this.nextDayEvents = const [],
    this.onEventTap,
  });

  final List<BabyEvent> events;
  final Baby baby;
  final DayMode dayMode;
  final DateTime activeDay;
  // Events from the day before activeDay — used to locate bedtime in early-morning night mode.
  final List<BabyEvent> previousDayEvents;
  // Events from the day after activeDay — used to show the actual morningWake
  // of the next day when viewing a historical night in evening mode.
  final List<BabyEvent> nextDayEvents;
  final void Function(BabyEvent)? onEventTap;

  @override
  State<TimelineBar> createState() => _TimelineBarState();
}

class _TimelineBarState extends State<TimelineBar> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // Hardcoded defaults: morningWake=08:00, bedtime=00:00 (midnight).
  // estimatedMorningWake/estimatedBedtime from baby are ONLY used by ComputeDayMode,
  // never as timeline visual bounds. The CF updates those fields after ≥5 days of data.
  static const _defaultMorning = '08:00';
  static const _defaultBedtime = '00:00';

  DateTime get _timelineStart {
    // +1 min: clean visual break — the transition event (bedtime/morningWake)
    // sits at the END of the previous mode, not the start of the next one.
    const gap = Duration(minutes: 1);

    if (widget.dayMode == DayMode.night) {
      final now = AppDateUtils.nowMadrid();
      final morningCutoff = _parseTime(_defaultMorning, widget.activeDay);
      if (now.isBefore(morningCutoff)) {
        // Early morning (after midnight): night started at yesterday's bedtime.
        // Bedtime's dayKey == yesterday, so search previousDayEvents first.
        final prevDay = widget.activeDay.subtract(const Duration(days: 1));
        final bedtime = _findEventIn(widget.previousDayEvents, EventType.bedtime) ??
            _findEventIn(widget.events, EventType.bedtime);
        return (bedtime?.startAt ?? _parseTime(_defaultBedtime, prevDay)).add(gap);
      }
      // Evening: night starts at today's bedtime (or tonight's midnight).
      final nextDay = widget.activeDay.add(const Duration(days: 1));
      return (_findEventIn(widget.events, EventType.bedtime)?.startAt ??
              _parseTime(_defaultBedtime, nextDay))
          .add(gap);
    }
    // Day mode: starts 1 min after morningWake (or 08:01 by default).
    return (_findEventIn(widget.events, EventType.morningWake)?.startAt ??
            _parseTime(_defaultMorning, widget.activeDay))
        .add(gap);
  }

  DateTime get _timelineEnd {
    if (widget.dayMode == DayMode.night) {
      final now = AppDateUtils.nowMadrid();
      final morningCutoff = _parseTime(_defaultMorning, widget.activeDay);
      if (now.isBefore(morningCutoff)) {
        // Early morning: ends at today's morningWake event or 08:00.
        return _findEventIn(widget.events, EventType.morningWake)?.startAt ??
            _parseTime(_defaultMorning, widget.activeDay);
      }
      // Evening: ends at the next day's actual morningWake (historical viewing)
      // or defaults to 08:00 of the next day for a live/future night.
      final nextDay = widget.activeDay.add(const Duration(days: 1));
      return _findEventIn(widget.nextDayEvents, EventType.morningWake)?.startAt ??
          _parseTime(_defaultMorning, nextDay);
    }
    // Day mode: ends at bedtime event or midnight (00:00 next day) by default.
    final nextDay = widget.activeDay.add(const Duration(days: 1));
    return _findEventIn(widget.events, EventType.bedtime)?.startAt ??
        _parseTime(_defaultBedtime, nextDay);
  }

  BabyEvent? _findEventIn(List<BabyEvent> events, EventType type) {
    try {
      return events.lastWhere((e) => e.type == type);
    } catch (_) {
      return null;
    }
  }

  // In night mode the events that occurred during the night window belong to
  // the previous dayKey (yesterday's morning_wake is the anchor). We must
  // combine both lists so blocks/markers from both days are rendered.
  List<BabyEvent> get _allVisibleEvents {
    if (widget.dayMode == DayMode.night) {
      final combined = [...widget.previousDayEvents, ...widget.events];
      final seen = <String>{};
      return combined.where((e) => seen.add(e.id)).toList();
    }
    return widget.events;
  }

  DateTime _parseTime(String t, DateTime day) {
    final parts = t.split(':');
    return DateTime(
        day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  String _fmtHHMM(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final start = _timelineStart;
    var end = _timelineEnd;

    // Guard: ensure end is at least 1h after start
    if (!end.isAfter(start.add(const Duration(hours: 1)))) {
      end = start.add(const Duration(hours: 8));
    }

    final totalMins = end.difference(start).inMinutes.toDouble();
    final now = AppDateUtils.nowMadrid();

    final axisColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);
    final trackColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'LÍNEA DEL DÍA',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
              const Spacer(),
              Text(
                '${_fmtHHMM(start)} – ${_fmtHHMM(end)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Plot area
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;

              double pct(DateTime t) {
                final m = t.difference(start).inMinutes.toDouble();
                return (m / totalMins).clamp(0.0, 1.0);
              }

              double xOf(DateTime t) => pct(t) * w;

              final nowPct = now.isAfter(start) && now.isBefore(end)
                  ? pct(now)
                  : (now.isAfter(end) ? 1.0 : 0.0);
              final showNow = now.isAfter(start) && now.isBefore(end);

              return SizedBox(
                height: 120,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Start icon (sun in day, moon in night)
                    Positioned(
                      top: 46,
                      left: 0,
                      child: PhosphorIcon(
                        widget.dayMode == DayMode.day
                            ? PhosphorIconsFill.sun
                            : PhosphorIconsFill.moon,
                        size: 14,
                        color: widget.dayMode == DayMode.day
                            ? AppColors.morningWakeColor
                            : AppColors.napColor,
                      ),
                    ),
                    // End icon (moon in day, sun in night)
                    Positioned(
                      top: 46,
                      right: 0,
                      child: PhosphorIcon(
                        widget.dayMode == DayMode.day
                            ? PhosphorIconsFill.moon
                            : PhosphorIconsFill.sun,
                        size: 14,
                        color: widget.dayMode == DayMode.day
                            ? AppColors.napColor
                            : AppColors.morningWakeColor,
                      ),
                    ),
                    // Full axis track (background)
                    Positioned(
                      top: 58,
                      left: 0,
                      right: 0,
                      height: 2,
                      child: Container(color: trackColor),
                    ),
                    // Past axis
                    Positioned(
                      top: 58,
                      left: 0,
                      width: nowPct * w,
                      height: 2,
                      child: Container(color: axisColor),
                    ),
                    // Future axis (dashed)
                    Positioned(
                      top: 58,
                      left: nowPct * w,
                      right: 0,
                      height: 2,
                      child: _DashedLine(color: axisColor),
                    ),

                    // Hour marks every 2h
                    ..._buildHourMarks(start, end, w, xOf, context, axisColor),

                    // Duration blocks (top:30, height:22) — only events that overlap with [start, end]
                    ..._allVisibleEvents
                        .where((e) => e.type.isDuration)
                        .where((e) => e.startAt.isBefore(end) && (e.endAt ?? now).isAfter(start))
                        .map((e) {
                          final bs = e.startAt.isAfter(start)
                              ? e.startAt
                              : start;
                          final be = (e.endAt ?? now).isBefore(end)
                              ? (e.endAt ?? now)
                              : end;
                          if (!bs.isBefore(be)) return const SizedBox.shrink();
                          final left = xOf(bs);
                          // Ensure clamp upper >= lower; event near right edge gets min 3px.
                          final available = (w - left).clamp(3.0, double.infinity);
                          final width = (xOf(be) - left).clamp(3.0, available);
                          return Positioned(
                            top: 30,
                            left: left,
                            width: width,
                            height: 22,
                            child: GestureDetector(
                              onTap: () => widget.onEventTap?.call(e),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: e.type.color,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Center(
                                  child: PhosphorIcon(
                                    e.type.icon,
                                    size: 11,
                                    color: AppColors.onPrimaryLight,
                                  ),
                                ),
                              ),
                            ),
                          );
                        })
                        .toList(),

                    // Instant event markers (top:70, size:24, centered)
                    ..._allVisibleEvents
                        .where((e) => !e.type.isDuration)
                        .where((e) => !e.startAt.isBefore(start) && !e.startAt.isAfter(end))
                        .map((e) {
                          final x = xOf(e.startAt);
                          return Positioned(
                            top: 70,
                            left: x - 12,
                            child: GestureDetector(
                              onTap: () => widget.onEventTap?.call(e),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: e.type.color,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: e.type.color.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Center(
                                  child: PhosphorIcon(
                                    e.type.icon,
                                    size: 11,
                                    color: AppColors.onPrimaryLight,
                                  ),
                                ),
                              ),
                            ),
                          );
                        })
                        .toList(),

                    // NOW indicator
                    if (showNow)
                      Positioned(
                        top: 0,
                        left: (nowPct * w - 20).clamp(0.0, w - 40),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'AHORA',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary,
                                ),
                              ),
                            ),
                            Container(
                              width: 2,
                              height: 78,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          // Legend — only types present in visible events
          Builder(builder: (context) {
            final presentTypes = _allVisibleEvents.map((e) => e.type).toSet();
            final allEntries = [
              (EventType.nap, 'Siesta'),
              (EventType.bedtime, 'Ir a la cama'),
              (EventType.nightWake, 'Despertar nocturno'),
              (EventType.morningWake, 'Despertar mañana'),
              (EventType.nursing, 'Toma'),
              (EventType.bottle, 'Biberón'),
            ];
            final visible = allEntries
                .where((entry) => presentTypes.contains(entry.$1))
                .toList();
            if (visible.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: visible
                      .map((e) => _LegendDot(color: e.$1.color, label: e.$2))
                      .toList(),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  List<Widget> _buildHourMarks(
    DateTime start,
    DateTime end,
    double width,
    double Function(DateTime) xOf,
    BuildContext context,
    Color axisColor,
  ) {
    final marks = <Widget>[];
    // Start from the first even hour after timeline start
    var h = start.hour + (start.minute > 0 ? 1 : 0);
    // Round up to next even hour
    if (h % 2 != 0) h++;

    while (true) {
      // Build candidate time (may overflow into next day for night mode)
      final base = h < 24
          ? DateTime(start.year, start.month, start.day, h)
          : DateTime(start.year, start.month, start.day + 1, h - 24);

      if (!base.isBefore(end)) break;
      if (base.isAfter(start)) {
        final x = xOf(base);
        marks.add(Positioned(
          top: 50,
          left: x - 0.5,
          child: Column(
            children: [
              Container(
                width: 1,
                height: 10,
                color: axisColor.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 2),
              Text(
                _fmtHH(base),
                style: TextStyle(
                  fontSize: 9,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ));
      }
      h += 2;
    }
    return marks;
  }

  String _fmtHH(DateTime t) =>
      '${(t.hour % 24).toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      const dashW = 4.0;
      const gapW = 4.0;
      final count = (constraints.maxWidth / (dashW + gapW)).floor();
      return Row(
        children: List.generate(count, (_) => Row(children: [
          Container(width: dashW, height: 2, color: color),
          const SizedBox(width: gapW),
        ])),
      );
    });
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

