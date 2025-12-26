import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../models/series.dart';
import '../../models/episode_progress.dart';
import '../../providers/watchlist_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/episode_progress_provider.dart';
import '../../providers/language_provider.dart';
import '../../core/widgets/image_with_placeholder.dart';
import '../../utils/series_progress_util.dart';
import '../widgets/mobile_page_route.dart';
import 'mobile_series_detail_screen.dart';

/// Status screen showing series organized by To Do, In Progress, Finished
class MobileStatusScreen extends StatefulWidget {
  const MobileStatusScreen({super.key});

  @override
  State<MobileStatusScreen> createState() => _MobileStatusScreenState();
}

class _MobileStatusScreenState extends State<MobileStatusScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _currentUserId;
  List<Series> _toDoSeries = [];
  List<Series> _inProgressSeries = [];
  List<Series> _finishedSeries = [];
  String? _errorMessage;
  bool _isLoading = true;
  bool _isRefreshing = false;
  DateTime? _lastLoadTime;
  static const _cacheTimeout = Duration(seconds: 30); // Cache for 30 seconds

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when returning to this screen (e.g., after completing a series)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isLoading && !_isRefreshing) {
        // Only refresh if cache expired
        final now = DateTime.now();
        if (_lastLoadTime == null || 
            now.difference(_lastLoadTime!) > _cacheTimeout) {
          _loadUserData();
        }
      }
    });
  }

  void _refreshData() {
    if (!_isLoading && !_isRefreshing && mounted) {
      _isRefreshing = true;
      _loadUserData().then((_) {
        if (mounted) {
          setState(() {
            _isRefreshing = false;
          });
        }
      }).catchError((_) {
        if (mounted) {
          setState(() {
            _isRefreshing = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Future<void> _loadUserData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
    final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
    
    final userId = _extractUserId(auth.token);
    if (userId == null) {
      // If no user ID, set loading to false and return
      if (mounted) {
        setState(() {
          _isLoading = false;
          _toDoSeries = [];
          _inProgressSeries = [];
          _finishedSeries = [];
        });
      }
      return;
    }
    
    _currentUserId = userId;
    
    // Set loading state at the start
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null; // Clear any previous errors
      });
    }

    try {
      // Only reload watchlist if it's empty or cache expired
      final now = DateTime.now();
      final shouldReload = watchlistProvider.items.isEmpty || 
                          _lastLoadTime == null ||
                          now.difference(_lastLoadTime!) > _cacheTimeout;
      
      if (shouldReload) {
        await watchlistProvider.loadWatchlist();
        _lastLoadTime = now;
      }
      
      final allItems = watchlistProvider.items;
      
      // Handle empty watchlist - API returns 200 OK but list is empty
      if (allItems.isEmpty) {
        if (mounted) {
          setState(() {
            _toDoSeries = [];
            _inProgressSeries = [];
            _finishedSeries = [];
            _isLoading = false;
          });
        }
        return;
      }
      
      // Categorize based on series-level progress
      final toDo = <Series>[];
      final inProgress = <Series>[];
      final finished = <Series>[];
      
      // Load ALL series progress in PARALLEL (much faster!)
      // Use silent loading to avoid UI flickering from multiple loading state changes
      final progressFutures = allItems.map((series) async {
        try {
          return await progressProvider.loadSeriesProgressSilent(series.id);
        } catch (e) {
          return null; // Return null on error so we don't block other series
        }
      }).toList();
      
      // Wait for all progress loads to complete in parallel
      // Use eagerError: false so one failure doesn't block others
      // Add timeout to prevent infinite loading
      final progressResults = await Future.wait(
        progressFutures,
        eagerError: false,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          return List<SeriesProgress?>.filled(allItems.length, null);
        },
      );
      
      // Now process each series with its progress
      for (int i = 0; i < allItems.length; i++) {
        final series = allItems[i];
        final progress = progressResults[i];
        
        try {
          // ALWAYS use backend's calculated values (they sum across ALL seasons correctly)
          // Backend calculates: totalEpisodes = series.Seasons.Sum(s => s.Episodes.Count)
          // Backend calculates: watchedEpisodes = all episodes across all seasons that are watched
          final totalEpisodes = progress?.totalEpisodes ?? 0;
          final watchedEpisodes = progress?.watchedEpisodes ?? 0;
          
          // Fallback: If backend didn't provide values, try calculating from series object
          // (but this is less reliable since series might not have seasons loaded)
          final effectiveTotalEpisodes = totalEpisodes > 0 
              ? totalEpisodes 
              : SeriesProgressUtil.calculateTotalEpisodes(series);
          
          // Only show series that have been started (watchedEpisodes > 0)
          // Series with 0 watched episodes should NOT appear in status screen
          if (!SeriesProgressUtil.shouldShowInStatus(watchedEpisodes)) {
            continue; // Skip series that haven't been started
          }
          
          // Determine status based on watchedEpisodes / totalEpisodes
          // Backend already calculated this correctly across all seasons
          final status = SeriesProgressUtil.determineStatus(watchedEpisodes, effectiveTotalEpisodes);
          
          switch (status) {
            case SeriesStatus.toDo:
              // This shouldn't happen due to the filter above, but keep for safety
              break;
            case SeriesStatus.inProgress:
              inProgress.add(series);
              break;
            case SeriesStatus.finished:
              finished.add(series);
              break;
          }
        } catch (e) {
          // If we can't process this series, skip it
          continue;
        }
      }
      
      // Always update state with results (even if lists are empty)
      if (mounted) {
        setState(() {
          _toDoSeries = toDo;
          _inProgressSeries = inProgress;
          _finishedSeries = finished;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle any errors - ensure loading state is cleared
      if (mounted) {
        setState(() {
          _toDoSeries = [];
          _inProgressSeries = [];
          _finishedSeries = [];
          _isLoading = false;
          _errorMessage = 'Failed to load status: ${e.toString()}';
        });
      }
    } finally {
      // Ensure loading state is ALWAYS set to false, even if something unexpected happens
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final userInfo = _getUserInfo(auth.token);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(languageProvider.translate('status')),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textLight),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.textLight,
          labelColor: AppColors.textLight,
          unselectedLabelColor: AppColors.textLight.withOpacity(0.7),
          tabs: [
            Tab(text: languageProvider.translate('toDo')),
            Tab(text: languageProvider.translate('inProgress')),
            Tab(text: languageProvider.translate('finished')),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: AppColors.dangerColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                                _isLoading = true;
                              });
                              _loadUserData();
                            },
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
                : Consumer<EpisodeProgressProvider>(
                    builder: (context, progressProvider, child) {
                      // Don't auto-refresh here - causes flickering
                      // Only refresh when explicitly triggered (pull-to-refresh or navigation)
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // User Profile Section at top
                          _buildUserProfileSection(theme),
                          // Tabs with series lists
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildSeriesList(_toDoSeries, theme),
                                _buildSeriesList(_inProgressSeries, theme),
                                _buildSeriesList(_finishedSeries, theme, showFullProgress: true),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildUserProfileSection(ThemeData theme) {
    final auth = Provider.of<AuthProvider>(context);
    final userInfo = _getUserInfo(auth.token);
    final username = userInfo['email']!.split('@')[0];

    return Container(
      padding: const EdgeInsets.all(AppDim.paddingLarge),
      color: AppColors.backgroundColor,
      child: Row(
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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  '@$username',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesList(List<Series> series, ThemeData theme, {bool showFullProgress = false}) {
    if (series.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_outlined,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppDim.paddingMedium),
            Text(
              'No series in this category',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDim.paddingMedium),
      itemCount: series.length,
      itemBuilder: (context, index) {
        final seriesItem = series[index];
        return _buildSeriesCard(seriesItem, theme, showFullProgress);
      },
    );
  }

  Widget _buildSeriesCard(Series series, ThemeData theme, bool showFullProgress) {
    // Get actual progress from provider
    return Consumer<EpisodeProgressProvider>(
      builder: (context, progressProvider, child) {
        final progress = progressProvider.getSeriesProgress(series.id);
        
        // ALWAYS prioritize backend's calculated values (sums across ALL seasons correctly)
        // Backend: totalEpisodes = sum of all episodes across all seasons
        // Backend: watchedEpisodes = count of watched episodes across all seasons
        final totalEpisodes = progress?.totalEpisodes ?? 0;
        final watchedEpisodes = progress?.watchedEpisodes ?? 0;
        
        // Fallback: If backend didn't provide values, calculate from series object
        final effectiveTotalEpisodes = totalEpisodes > 0 
            ? totalEpisodes 
            : SeriesProgressUtil.calculateTotalEpisodes(series);
        
        // Calculate progress percentage
        final progressPercentage = SeriesProgressUtil.calculateProgressPercentage(
          watchedEpisodes, 
          effectiveTotalEpisodes,
        );
        final progressValue = progressPercentage / 100.0;
        
        // Format progress text (e.g., "5/15 episodes")
        final progressText = SeriesProgressUtil.formatProgressText(
          watchedEpisodes, 
          effectiveTotalEpisodes,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: AppDim.paddingMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MobilePageRoute(
                  builder: (context) => MobileSeriesDetailScreen(series: series),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Series Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ImageWithPlaceholder(
                      imageUrl: series.imageUrl,
                      width: 80,
                      height: 120,
                      fit: BoxFit.cover,
                      placeholderIcon: Icons.movie,
                      placeholderIconSize: 40,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Series Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          series.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          progressText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 8),
                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: AppColors.primaryColor.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

