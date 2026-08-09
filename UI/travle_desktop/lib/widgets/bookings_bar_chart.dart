import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';

/// A single-series bar chart of bookings per month over the trailing year. One brand
/// hue, recessive gridlines/axes, a per-bar hover tooltip, and no legend (the caption
/// names the series) — per the shared dataviz guidance. Theme-aware for light/dark.
class BookingsBarChart extends StatelessWidget {
  const BookingsBarChart({super.key, required this.points, this.height = 220});

  final List<MonthlyBookingPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bar = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    final gridColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);

    final maxCount = points.fold<int>(0, (m, p) => math.max(m, p.count));
    final interval = math.max(1, (maxCount / 4).ceil()).toDouble();
    final maxY = maxCount == 0 ? interval : (maxCount + interval * 0.6);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: 0,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              getTooltipItem: (group, _, _, _) {
                final point = points[group.x];
                return BarTooltipItem(
                  '${point.label}\n',
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text:
                          '${point.count} '
                          '${point.count == 1 ? 'booking' : 'bookings'}',
                      style: TextStyle(
                        color: theme.colorScheme.onInverseSurface.withValues(
                          alpha: 0.85,
                        ),
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: gridColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value % interval != 0) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      value.toInt().toString(),
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  // "Aug 2026" → "Aug"; the tooltip carries the full label + year.
                  final month = points[index].label.split(' ').first;
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      month,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: points[i].count.toDouble(),
                    color: bar,
                    width: 16,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
        // Disable the implicit swap animation: on desktop, hovering restarts it and
        // the animation tick re-enters Flutter's mouse-tracker pass, throwing the
        // '!_debugDuringDeviceUpdate' assertion repeatedly. Zero duration avoids it.
        duration: Duration.zero,
      ),
    );
  }
}
