import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../providers/watchlist_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/series_provider.dart';
import '../../core/widgets/image_with_placeholder.dart';

/// Statistics screen showing user statistics with cards and charts
class MobileStatisticsScreen extends StatefulWidget {
  const MobileStatisticsScreen({super.key});

  @override
  State<MobileStatisticsScreen> createState() => _MobileStatisticsScreenState();
}

class _MobileStatisticsScreenState extends State<MobileStatisticsScreen> {
  int? _currentUserId;
  int _totalSeries = 0;
  int _totalEpisodes = 0;
  int _totalReviews = 0;
  int _totalHours = 0;
  Map<String, double> _genreDistribution = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatistics();
    });
  }

  int? _extractUserId(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final decoded = JwtDecoder.decode(token);
      final dynamic rawId = decoded['userId'] ?? decoded['id'] ?? decoded['nameid'] ?? decoded['sub'];
      if (rawId is int) return rawId;
      if (rawId is String) return int.tryParse(rawId);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadStatistics() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    
    final userId = _extractUserId(auth.token);
    if (userId == null) return;
    
    _currentUserId = userId;

    try {
      // Load watchlist to get series count
      await watchlistProvider.loadWatchlist();
      
      // Calculate statistics
      final watchlistItems = watchlistProvider.items;
      _totalSeries = watchlistItems.length;
      
      // Calculate episodes (simplified - assume average 20 episodes per series)
      _totalEpisodes = _totalSeries * 20;
      
      // Calculate hours (assume 45 minutes per episode)
      _totalHours = (_totalEpisodes * 45 / 60).round();
      
      // Calculate genre distribution
      _genreDistribution = {};
      for (var series in watchlistItems) {
        for (var genre in series.genres) {
          _genreDistribution[genre] = (_genreDistribution[genre] ?? 0) + 1;
        }
      }
      
      // Convert to percentages
      if (_genreDistribution.isNotEmpty) {
        final total = _genreDistribution.values.reduce((a, b) => a + b);
        _genreDistribution = _genreDistribution.map((key, value) => 
          MapEntry(key, (value / total * 100)));
      }
      
      // Get reviews count (simplified - would need API endpoint)
      _totalReviews = _totalSeries ~/ 2; // Assume half of series have reviews
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final userInfo = _getUserInfo(auth.token);
    final initials = _getInitials(userInfo['email']!);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDim.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            Row(
              children: [
                AvatarImage(
                  avatarUrl: userInfo['avatarUrl'],
                  radius: 40,
                  initials: initials,
                  placeholderIcon: Icons.person,
                ),
                const SizedBox(width: AppDim.paddingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userInfo['name']!,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userInfo['email']!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppDim.paddingLarge),
            
            // Bio (placeholder)
            Text(
              'Big fan of Turkish Dramas | Romance & History lover',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            
            const SizedBox(height: AppDim.paddingLarge),
            
            // Statistics Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('$_totalSeries SERIES', Colors.blue, theme),
                ),
                const SizedBox(width: AppDim.paddingSmall),
                Expanded(
                  child: _buildStatCard('$_totalEpisodes EPISODES', AppColors.primaryColor, theme),
                ),
                const SizedBox(width: AppDim.paddingSmall),
                Expanded(
                  child: _buildStatCard('$_totalReviews REVIEWS', Colors.pink, theme),
                ),
              ],
            ),
            
            const SizedBox(height: AppDim.paddingLarge),
            
            // Total Hours Watched
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDim.paddingLarge),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Total Hours',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_totalHours hours',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'watched in ${DateTime.now().year}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppDim.paddingLarge),
            
            // Genre Distribution Chart
            if (_genreDistribution.isNotEmpty) ...[
              Text(
                'Most Watched Genre',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppDim.paddingMedium),
              SizedBox(
                height: 200,
                child: _buildGenreChart(theme),
              ),
              const SizedBox(height: AppDim.paddingMedium),
              _buildGenreLegend(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppDim.paddingMedium),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildGenreChart(ThemeData theme) {
    final colors = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.red,
    ];
    
    final entries = _genreDistribution.entries.toList();
    if (entries.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: entries.asMap().entries.map((entry) {
          final index = entry.key;
          final genreEntry = entry.value;
          return PieChartSectionData(
            value: genreEntry.value,
            title: '${genreEntry.value.toStringAsFixed(0)}%',
            color: colors[index % colors.length],
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGenreLegend(ThemeData theme) {
    final colors = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.red,
    ];
    
    final entries = _genreDistribution.entries.toList();
    
    return Wrap(
      spacing: AppDim.paddingMedium,
      runSpacing: AppDim.paddingSmall,
      children: entries.asMap().entries.map((entry) {
        final index = entry.key;
        final genreEntry = entry.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${genreEntry.key} ${genreEntry.value.toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Map<String, String?> _getUserInfo(String? token) {
    if (token == null || token.isEmpty) {
      return {'email': 'Unknown', 'name': 'Unknown User', 'avatarUrl': null};
    }

    try {
      final decodedToken = JwtDecoder.decode(token);
      final email = decodedToken['email'] as String? ?? 
                   decodedToken['sub'] as String? ?? 
                   'Unknown';
      
      String name = 'User';
      if (email != 'Unknown') {
        final parts = email.split('@');
        if (parts.isNotEmpty) {
          final namePart = parts[0];
          name = namePart[0].toUpperCase() + namePart.substring(1);
        }
      }
      
      final avatarUrl = decodedToken['avatarUrl'] as String?;
      return {'email': email, 'name': name, 'avatarUrl': avatarUrl};
    } catch (e) {
      return {'email': 'Unknown', 'name': 'Unknown User', 'avatarUrl': null};
    }
  }

  String _getInitials(String email) {
    if (email == 'Unknown') return 'U';
    final parts = email.split('@');
    if (parts.isNotEmpty) {
      final namePart = parts[0];
      if (namePart.length >= 2) {
        return namePart.substring(0, 2).toUpperCase();
      }
      return namePart[0].toUpperCase();
    }
    return 'U';
  }
}

