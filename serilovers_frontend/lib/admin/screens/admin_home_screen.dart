import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../models/user.dart';
import '../../models/series.dart';
import '../providers/admin_statistics_provider.dart';
import '../../providers/admin_user_provider.dart';
import '../providers/admin_series_provider.dart';

/// Admin home screen with modern dashboard layout using real database data
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  /// Load all necessary data
  Future<void> _loadData() async {
    try {
      // Fetch statistics
      final statsProvider = Provider.of<AdminStatisticsProvider>(context, listen: false);
      if (statsProvider.stats == null) {
        await statsProvider.fetchStats();
      }

      // Fetch recent users (last 5, sorted by dateCreated desc)
      final userProvider = Provider.of<AdminUserProvider>(context, listen: false);
      await userProvider.fetchFiltered(
        sortBy: 'dateCreated',
        sortOrder: 'desc',
        page: 1,
        pageSize: 5,
      );

      // Fetch recent series (last 5, sorted by releaseDate desc)
      final seriesProvider = Provider.of<AdminSeriesProvider>(context, listen: false);
      await seriesProvider.fetchFiltered(
        sortBy: 'year',
        sortOrder: 'desc',
        page: 1,
        pageSize: 5,
      );
    } catch (e) {
      print('Error loading admin home data: $e');
    }
  }

  /// Format date for display (e.g., "2 hours ago", "1 day ago")
  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: AppColors.backgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDim.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Text(
              'Dashboard Overview',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome back! Here\'s what\'s happening with your platform.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDim.paddingLarge),

            // Statistics Grid (4 cards) - Using real data from AdminStatisticsProvider
            Consumer<AdminStatisticsProvider>(
              builder: (context, statsProvider, child) {
                if (statsProvider.isLoading) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final totals = statsProvider.totals;
                return _buildStatisticsGrid(
                  context,
                  theme,
                  totals.users,
                  totals.series,
                  totals.actors,
                  totals.watchlistItems,
                );
              },
            ),
            const SizedBox(height: AppDim.paddingLarge),

            // Dashboard Sections Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recent Users Section - Using real data
                Expanded(
                  child: _buildRecentUsersSection(context, theme),
                ),
                const SizedBox(width: AppDim.paddingMedium),
                // Recently Added Series Section - Using real data
                Expanded(
                  child: _buildRecentSeriesSection(context, theme),
                ),
              ],
            ),
            const SizedBox(height: AppDim.paddingLarge),
          ],
        ),
      ),
    );
  }

  /// Builds the statistics grid with 4 cards using real data
  Widget _buildStatisticsGrid(
    BuildContext context,
    ThemeData theme,
    int totalUsers,
    int totalSeries,
    int totalActors,
    int totalWatchlists,
  ) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppDim.paddingMedium,
      mainAxisSpacing: AppDim.paddingMedium,
      childAspectRatio: 2.2,
      children: [
        _buildStatCard(
          context: context,
          title: 'Total Users',
          value: _formatNumber(totalUsers),
          icon: Icons.people,
          color: AppColors.primaryColor,
        ),
        _buildStatCard(
          context: context,
          title: 'Total Series',
          value: _formatNumber(totalSeries),
          icon: Icons.movie,
          color: const Color(0xFF6C5CE7),
        ),
        _buildStatCard(
          context: context,
          title: 'Total Actors',
          value: _formatNumber(totalActors),
          icon: Icons.person,
          color: const Color(0xFFA29BFE),
        ),
        _buildStatCard(
          context: context,
          title: 'Total Watchlists',
          value: _formatNumber(totalWatchlists),
          icon: Icons.bookmark,
          color: const Color(0xFF7B56F9),
        ),
      ],
    );
  }

  /// Formats number with comma separators
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// Builds a single statistic card
  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppDim.padding),
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
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDim.radiusSmall),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: AppDim.paddingMedium),
          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the Recent Users section using real data
  Widget _buildRecentUsersSection(BuildContext context, ThemeData theme) {
    return Container(
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
          // Header
          Padding(
            padding: const EdgeInsets.all(AppDim.padding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Users',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to users screen (can be implemented later)
                  },
                  child: Text(
                    'View All',
                    style: TextStyle(color: AppColors.primaryColor),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Users List - Using real data from AdminUserProvider
          Consumer<AdminUserProvider>(
            builder: (context, userProvider, child) {
              if (userProvider.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(AppDim.paddingLarge),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (userProvider.users.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppDim.paddingLarge),
                  child: Center(
                    child: Text(
                      'No users found',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }

              // Get last 5 users (already sorted by dateCreated desc from fetchFiltered)
              final recentUsers = userProvider.users.take(5).toList();

              return Column(
                children: recentUsers.map((user) => _buildUserRow(context, theme, user)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Builds a single user row
  Widget _buildUserRow(BuildContext context, ThemeData theme, User user) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDim.padding,
        vertical: AppDim.paddingSmall,
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryColor.withOpacity(0.1),
            child: Text(
              user.displayName.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppDim.paddingMedium),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Date
          Text(
            _formatDate(user.dateCreated),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the Recent Series section using real data
  Widget _buildRecentSeriesSection(BuildContext context, ThemeData theme) {
    return Container(
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
          // Header
          Padding(
            padding: const EdgeInsets.all(AppDim.padding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recently Added Series',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to series screen (can be implemented later)
                  },
                  child: Text(
                    'View All',
                    style: TextStyle(color: AppColors.primaryColor),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Series List - Using real data from AdminSeriesProvider
          Consumer<AdminSeriesProvider>(
            builder: (context, seriesProvider, child) {
              if (seriesProvider.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(AppDim.paddingLarge),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (seriesProvider.items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppDim.paddingLarge),
                  child: Center(
                    child: Text(
                      'No series found',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }

              // Get last 5 series (already sorted by year desc from fetchFiltered)
              final recentSeries = seriesProvider.items.take(5).toList();

              return Column(
                children: recentSeries.map((series) => _buildSeriesRow(context, theme, series)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Builds a single series row
  Widget _buildSeriesRow(BuildContext context, ThemeData theme, Series series) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDim.padding,
        vertical: AppDim.paddingSmall,
      ),
      child: Row(
        children: [
          // Series Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDim.radiusSmall),
            ),
            child: Icon(
              Icons.movie,
              color: AppColors.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppDim.paddingMedium),
          // Series Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  series.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      series.releaseDate.year.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppDim.paddingSmall),
                    Icon(
                      Icons.star,
                      size: 14,
                      color: AppColors.primaryColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      series.rating.toStringAsFixed(1),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Date
          Text(
            _formatDate(series.releaseDate),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
