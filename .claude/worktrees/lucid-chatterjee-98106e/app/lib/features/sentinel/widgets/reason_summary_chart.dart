import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Bar-chart summary of flagged-transaction counts by anomaly reason.
///
/// This is a magnitude comparison across a handful of categories, so it
/// follows the single-hue-by-magnitude rule: every bar uses the same brand
/// color rather than a rainbow. Reason strings are too long for x-axis
/// labels, so bars are numbered (#1, #2, ...) and the caller renders a
/// ranked legend/table underneath (see `SentinelScreen`) — the "table view"
/// fallback for anything the chart alone can't label.
class ReasonSummaryChart extends StatelessWidget {
  const ReasonSummaryChart({required this.summaryByReason, super.key});

  final Map<String, int> summaryByReason;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, int>> entries = summaryByReason.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
    final int maxCount = entries.isEmpty ? 1 : entries.map((MapEntry<String, int> e) => e.value).reduce(math.max);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: (maxCount * 1.25).clamp(1, double.infinity).toDouble(),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.brandPrimary,
              getTooltipItem: (BarChartGroupData group, int _, BarChartRodData rod, int __) {
                final String reason = entries[group.x.toInt()].key;
                return BarTooltipItem(
                  '$reason\n${rod.toY.round()} flagged',
                  const TextStyle(color: Colors.white, fontSize: 11.5),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (double value, TitleMeta meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int idx = value.toInt();
                  if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '#${idx + 1}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: <BarChartGroupData>[
            for (int i = 0; i < entries.length; i++)
              BarChartGroupData(
                x: i,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: entries[i].value.toDouble(),
                    color: AppColors.brandPrimary,
                    width: 22,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
