import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../providers/admin_statistics_provider.dart';
import '../models/admin_statistics.dart';

/// Admin statistics screen with dashboard cards, charts, and data tables
class AdminStatisticsScreen extends StatefulWidget {
  const AdminStatisticsScreen({super.key});

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends State<AdminStatisticsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch statistics when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminStatisticsProvider>(context, listen: false).fetchStats();
    });
  }

  /// Build a statistics card (matching HOME screen style)
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      width: 180,
      padding: const EdgeInsets.all(AppDim.padding),
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.circular(AppDim.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            icon,
            color: AppColors.textLight,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.textLight,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textLight.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// Build pie chart for genre distribution using fl_chart
  Widget _buildGenreChart(List<GenreDistribution> data) {
    if (data.isEmpty) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(AppDim.paddingLarge),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDim.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pie_chart,
                size: 64,
                color: AppColors.textSecondary.withOpacity(0.3),
              ),
              const SizedBox(height: AppDim.paddingMedium),
              Text(
                'No data available',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Generate colors for pie chart - use primary color variations
    final colors = [
      AppColors.primaryColor,
      AppColors.primaryColor.withOpacity(0.8),
      AppColors.primaryColor.withOpacity(0.6),
      AppColors.accentColor,
      AppColors.accentColor.withOpacity(0.8),
      Colors.blue.shade400,
      Colors.purple.shade300,
      Colors.indigo.shade300,
    ];

    return Container(
      height: 300,
      padding: const EdgeInsets.all(AppDim.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDim.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Genre Distribution',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppDim.paddingMedium),
          Expanded(
            child: Row(
              children: [
                // Pie Chart
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: data.asMap().entries.map((entry) {
                        final index = entry.key;
                        final genre = entry.value;
                        return PieChartSectionData(
                          value: genre.percentage,
                          title: '${genre.percentage.toStringAsFixed(1)}%',
                          color: colors[index % colors.length],
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textLight,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Legend
                Expanded(
                  flex: 1,
                  child: ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final genre = data[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppDim.paddingSmall),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppDim.paddingSmall),
                            Expanded(
                              child: Text(
                                genre.genre,
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${genre.percentage.toStringAsFixed(1)}%',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build line chart for monthly watching using fl_chart
  Widget _buildMonthlyChart(List<MonthlyWatching> data) {
    if (data.isEmpty) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(AppDim.paddingLarge),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDim.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.show_chart,
                size: 64,
                color: AppColors.textSecondary.withOpacity(0.3),
              ),
              const SizedBox(height: AppDim.paddingMedium),
              Text(
                'No data available',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final maxValue = data.map((m) => m.views).reduce((a, b) => a > b ? a : b);
    final minValue = 0;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(AppDim.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDim.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Watching',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppDim.paddingMedium),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue > 0 ? (maxValue / 5).ceilToDouble() : 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.textSecondary.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
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
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              data[value.toInt()].monthYearLabel,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: AppColors.textSecondary.withOpacity(0.2),
                  ),
                ),
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: minValue.toDouble(),
                maxY: maxValue > 0 ? maxValue * 1.1 : 10,
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.views.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: AppColors.primaryColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(
                      show: true,
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primaryColor.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      color: AppColors.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(AppDim.paddingLarge),
        child: Consumer<AdminStatisticsProvider>(
        builder: (context, statsProvider, child) {
          // Show error SnackBar if error exists
          if (statsProvider.error != null && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Error loading statistics:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statsProvider.error ?? 'Unknown error',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.dangerColor,
                    duration: const Duration(seconds: 10),
                    action: SnackBarAction(
                      label: 'Retry',
                      textColor: Colors.white,
                      onPressed: () => statsProvider.fetchStats(),
                    ),
                  ),
                );
              }
            });
          }

          if (statsProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Show error message if there's an error and no data
          if (statsProvider.error != null && statsProvider.stats == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDim.paddingLarge),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.dangerColor,
                    ),
                    const SizedBox(height: AppDim.paddingMedium),
                    Text(
                      'Failed to load statistics',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppDim.paddingSmall),
                    Text(
                      statsProvider.error ?? 'Unknown error',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDim.paddingLarge),
                    ElevatedButton.icon(
                      onPressed: () => statsProvider.fetchStats(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final totals = statsProvider.totals;

          return SingleChildScrollView(
        padding: const EdgeInsets.all(AppDim.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                // Title and refresh button
                Row(
                  children: [
            Text(
                      'Statistics Dashboard',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => statsProvider.refresh(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: AppColors.textLight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDim.paddingMedium,
                          vertical: AppDim.paddingSmall,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDim.paddingLarge),

                // Top cards row (4 metric cards using provider.totals)
                SizedBox(
                  height: 140,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildStatCard(
                        title: 'Total Users',
                        value: totals.users.toString(),
                        icon: Icons.people,
                      ),
                      const SizedBox(width: AppDim.padding),
                      _buildStatCard(
                        title: 'Total Series',
                        value: totals.series.toString(),
                        icon: Icons.movie,
                      ),
                      const SizedBox(width: AppDim.padding),
                      _buildStatCard(
                        title: 'Total Actors',
                        value: totals.actors.toString(),
                        icon: Icons.person,
                      ),
                      const SizedBox(width: AppDim.padding),
                      _buildStatCard(
                        title: 'Watchlist Items',
                        value: totals.watchlistItems.toString(),
                        icon: Icons.bookmark,
                      ),
                    ],
                  ),
            ),
            const SizedBox(height: AppDim.paddingLarge),

                // Two-column layout: Genre chart and Monthly chart
                Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Expanded(
                      child: _buildGenreChart(statsProvider.genreDistribution),
                    ),
                    const SizedBox(width: AppDim.paddingMedium),
                  Expanded(
                      child: _buildMonthlyChart(statsProvider.monthlyWatching),
                    ),
                  ],
                ),
                const SizedBox(height: AppDim.paddingLarge),

                // Top Rated Series DataTable
                Container(
                  padding: const EdgeInsets.all(AppDim.paddingLarge),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top Rated Series',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      const SizedBox(height: AppDim.paddingMedium),
                      statsProvider.topSeries.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppDim.paddingLarge),
                                child: Text(
                                  'No data available',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(
                                  AppColors.primaryColor.withOpacity(0.1),
                                ),
                                columns: const [
                                  DataColumn(label: Text('Title')),
                                  DataColumn(
                                    label: Text('Average Rating'),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text('Views'),
                                    numeric: true,
                                  ),
                                ],
                                rows: statsProvider.topSeries.map((series) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          series.title,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.star,
                                              size: 16,
                                              color: AppColors.primaryColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              series.avgRating.toStringAsFixed(1),
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          series.views.toString(),
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
          );
        },
        ),
      ),
    );
  }
}
