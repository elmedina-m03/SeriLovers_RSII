import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../models/genre_distribution.dart';

/// Bar chart widget for displaying genre distribution
class GenreBarChart extends StatelessWidget {
  /// List of genre distribution statistics
  final List<GenreDistribution> stats;

  const GenreBarChart({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Center(
        child: Text('No genre data available'),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxCount() * 1.2, // Add 20% padding at top
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppColors.primaryColor,
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final genre = stats[groupIndex];
              return BarTooltipItem(
                '${genre.genreName}\n${genre.count}',
                const TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < stats.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      stats[index].genreName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color: AppColors.textPrimary.withOpacity(0.2),
              width: 1,
            ),
            left: BorderSide(
              color: AppColors.textPrimary.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getMaxCount() / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.textPrimary.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        barGroups: stats.asMap().entries.map((entry) {
          final index = entry.key;
          final genre = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: genre.count.toDouble(),
                color: AppColors.primaryColor,
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Gets the maximum count from stats for scaling
  double _getMaxCount() {
    if (stats.isEmpty) return 10;
    return stats.map((s) => s.count.toDouble()).reduce((a, b) => a > b ? a : b);
  }
}

