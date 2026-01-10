import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../providers/watchlist_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/series_provider.dart';
import '../../providers/episode_progress_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/episode_progress_service.dart';
import '../../services/rating_service.dart';
import '../../core/widgets/image_with_placeholder.dart';
import '../../models/series.dart';

/// Statistics screen showing user statistics with cards and charts
class MobileStatisticsScreen extends StatefulWidget {
  const MobileStatisticsScreen({super.key});

  @override
  State<MobileStatisticsScreen> createState() => _MobileStatisticsScreenState();
}

class _MobileStatisticsScreenState extends State<MobileStatisticsScreen> {
  int? _currentUserId;
  int? _totalSeries;
  int? _totalEpisodes;
  int? _totalReviews;
  int? _totalHours;
  Map<String, double> _genreDistribution = {};
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _lastLoadTime;
  static const _cacheTimeout = Duration(seconds: 30); // Cache for 30 seconds

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatistics();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when returning to this screen (e.g., after completing a series)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isLoading) {
        final now = DateTime.now();
        if (_lastLoadTime == null || 
            now.difference(_lastLoadTime!) > _cacheTimeout) {
          _loadStatistics();
        }
      }
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
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    final progressService = EpisodeProgressService();
    final ratingService = RatingService();
    
    final userId = _extractUserId(auth.token);
    if (userId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not authenticated';
        });
      }
      return;
    }
    
    _currentUserId = userId;

    try {
      final token = auth.token;
      if (token == null || token.isEmpty) return;

      // Only reload watchlist if it's empty or cache expired
      final now = DateTime.now();
      final shouldReload = watchlistProvider.items.isEmpty || 
                          _lastLoadTime == null ||
                          now.difference(_lastLoadTime!) > _cacheTimeout;
      
      if (shouldReload) {
        await watchlistProvider.loadWatchlist();
        _lastLoadTime = now;
      }
      
      // Get all series with status (includes series with progress even if not in watchlist)
      final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
      final allSeriesWithStatus = await progressProvider.getUserSeriesWithStatus();
      
      // Separate series by status
      final finishedSeries = <Series>[];
      final inProgressSeries = <Series>[];
      final toDoSeries = <Series>[];
      
      int totalWatchedEpisodes = 0;
      double totalMinutes = 0.0;
      
      // Process all series with their status
      for (final item in allSeriesWithStatus) {
        final seriesData = item['series'] as Map<String, dynamic>?;
        if (seriesData == null) continue;
        
        final series = Series.fromJson(seriesData);
        final status = item['status'] as String? ?? 'ToWatch';
        final watchedEpisodes = (item['watchedEpisodes'] as num?)?.toInt() ?? 0;
        final totalEpisodes = (item['totalEpisodes'] as num?)?.toInt() ?? 0;
        
        // Count watched episodes
        totalWatchedEpisodes += watchedEpisodes;
        
        // Estimate hours from watched episodes (use average 40 min per episode)
        totalMinutes += watchedEpisodes * 40.0;
        
        // Categorize by status
        switch (status.toLowerCase()) {
          case 'finished':
            finishedSeries.add(series);
            break;
          case 'inprogress':
            inProgressSeries.add(series);
            break;
          case 'towatch':
          case 'todo':
            toDoSeries.add(series);
            break;
        }
      }
      
      // Also include watchlist series that might not have progress yet
      final watchlistItems = watchlistProvider.items;
      final existingSeriesIds = allSeriesWithStatus
          .map((item) => (item['series'] as Map<String, dynamic>?)?['id'] as int?)
          .where((id) => id != null)
          .cast<int>()
          .toSet();
      
      for (final series in watchlistItems) {
        if (!existingSeriesIds.contains(series.id)) {
          // Series in watchlist but no progress - add to "To Do"
          toDoSeries.add(series);
        }
      }
      
      // Set total series to finished series count (not total watchlist count)
      _totalSeries = finishedSeries.length;
      
      // Use watched episodes count from progress data (more accurate than loading all progress)
      _totalEpisodes = totalWatchedEpisodes;
      _totalHours = (totalMinutes / 60).round();
      
      // Calculate genre distribution from finished and in-progress series (not just watchlist)
      _genreDistribution = {};
      final allActiveSeries = [...finishedSeries, ...inProgressSeries];
      for (var series in allActiveSeries) {
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
      
      // Get reviews count for THIS SPECIFIC USER only (not all users)
      // Count ALL ratings (not just those with comments) - a rating is a review
      try {
        // getUserRatings filters by userId on backend - returns only this user's ratings
        final userRatings = await ratingService.getUserRatings(userId, token: token);
        // Count all ratings as reviews (a rating is a review, even without a comment)
        _totalReviews = userRatings.length;
      } catch (e) {
        // If endpoint fails, fallback to 0
        _totalReviews = 0;
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle error - show error message
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load statistics: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final userInfo = _getUserInfo(auth.token);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(languageProvider.translate('statistics')),
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
                ImageWithPlaceholder(
                  imageUrl: userInfo['avatarUrl'],
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  borderRadius: 6,
                  placeholderIcon: Icons.person,
                  placeholderIconSize: 20,
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
            
            // Bio - can be customized later if user profile has bio field
            // For now, show a default message or leave empty
            // Text(
            //   'Big fan of Turkish Dramas | Romance & History lover',
            //   style: theme.textTheme.bodyMedium?.copyWith(
            //     color: AppColors.textSecondary,
            //     fontStyle: FontStyle.italic,
            //   ),
            // ),
            
            const SizedBox(height: AppDim.paddingLarge),
            
            // Statistics Cards
            _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppDim.paddingLarge),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                      ),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDim.paddingLarge),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: AppColors.dangerColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadStatistics,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryColor,
                                  foregroundColor: AppColors.textLight,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              '${_totalSeries ?? 0} ${languageProvider.translate('series')}',
                              Colors.blue,
                              theme,
                            ),
                          ),
                          const SizedBox(width: AppDim.paddingSmall),
                          Expanded(
                            child: _buildStatCard(
                              '${_totalEpisodes ?? 0} ${languageProvider.translate('episodes')}',
                              AppColors.primaryColor,
                              theme,
                            ),
                          ),
                          const SizedBox(width: AppDim.paddingSmall),
                          Expanded(
                            child: _buildStatCard(
                              '${_totalReviews ?? 0} ${languageProvider.translate('reviews')}',
                              Colors.pink,
                              theme,
                            ),
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
                    languageProvider.translate('totalHours'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_totalHours ?? 0} ${languageProvider.translate('hours')}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${languageProvider.translate('watchedIn')} ${DateTime.now().year}',
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
                languageProvider.translate('mostWatchedGenre'),
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

