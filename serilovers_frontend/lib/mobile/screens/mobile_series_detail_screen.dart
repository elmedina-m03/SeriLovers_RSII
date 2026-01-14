import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../models/series.dart';
import '../../models/season.dart';
import '../../providers/series_provider.dart';
import '../../providers/watchlist_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/episode_progress_provider.dart';
import '../../providers/rating_provider.dart';
import '../../models/episode_progress.dart';
import '../../services/episode_progress_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../core/widgets/image_with_placeholder.dart';
import '../widgets/mark_episodes_dialog.dart';
import '../widgets/mobile_page_route.dart';
import '../widgets/season_selector.dart';
import 'mobile_reviews_screen.dart';
import 'mobile_series_description_screen.dart';
import '../providers/mobile_challenges_provider.dart';

/// Mobile series detail screen with banner, info, and watchlist button
class MobileSeriesDetailScreen extends StatefulWidget {
  final Series series;

  const MobileSeriesDetailScreen({
    super.key,
    required this.series,
  });

  @override
  State<MobileSeriesDetailScreen> createState() => _MobileSeriesDetailScreenState();
}

class _MobileSeriesDetailScreenState extends State<MobileSeriesDetailScreen> {
  late Series _series;
  bool _isDescriptionExpanded = false;
  int? _userRating; // User's rating (1-5)
  bool _isRatingLoading = false;
  int? _selectedSeasonNumber; // Currently selected season
  bool _isLoadingDetail = false;
  Set<int> _watchedEpisodeIds = {}; // Track watched episode IDs for UI updates
  Future<SeriesProgress?>? _progressFuture; // Cache the progress future to avoid rebuild loops
  int _favoriteRebuildKey = 0; // Key to force FutureBuilder rebuild after toggle

  @override
  void initState() {
    super.initState();
    _series = widget.series;
    // Load watchlist to check if series is already added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);

      // Try to refresh series details from provider if available
      final updated = seriesProvider.getById(widget.series.id);
      if (updated != null) {
        setState(() {
          _series = updated;
          // Auto-select first season if available
          if (_series.seasons.isNotEmpty && _selectedSeasonNumber == null) {
            _selectedSeasonNumber = _series.seasons.first.seasonNumber;
          }
        });
      }
      
      // Load full series detail with seasons and episodes
      _loadSeriesDetail();
      
      // Load legacy watchlist
      if (token != null && token.isNotEmpty && watchlistProvider.items.isEmpty) {
        watchlistProvider.fetchWatchlist(token).catchError((error) {
          // Silently fail - watchlist will be checked when button is pressed
        });
      }
      
      // Load user's watchlist collections (lists)
      if (token != null && token.isNotEmpty) {
        try {
          final decoded = JwtDecoder.decode(token);
          final rawId = decoded['userId'] ?? decoded['id'] ?? decoded['nameid'] ?? decoded['sub'];
          int? userId;
          if (rawId is int) {
            userId = rawId;
          } else if (rawId is String) {
            userId = int.tryParse(rawId);
          }
          
          if (userId != null && watchlistProvider.lists.isEmpty) {
            watchlistProvider.loadUserWatchlists(userId).catchError((_) {});
          }
        } catch (_) {
          // Silently fail
        }
      }

      // Load reviews for this series (public - doesn't require authentication)
      final ratingProvider = Provider.of<RatingProvider>(context, listen: false);
      ratingProvider.loadSeriesRatings(widget.series.id).catchError((_) {});
      
      // Load progress for this series (requires authentication)
      final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
      if (token != null && token.isNotEmpty) {
        // Load progress in post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _progressFuture = progressProvider.loadSeriesProgress(widget.series.id);
          _progressFuture!.then((_) {
            // Load watched episodes for UI indicators
            if (mounted) {
              _loadWatchedEpisodes();
            }
          }).catchError((_) {
            // Silently fail - progress will show as not started
            return null;
          });
        });
      }
    });
  }

  Future<void> _handleWatchlistToggle() async {
    final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to manage your watchlist'),
            backgroundColor: AppColors.dangerColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final isInWatchlist = watchlistProvider.isInWatchlist(widget.series.id);

    try {
      if (isInWatchlist) {
        await watchlistProvider.removeFromWatchlist(widget.series.id, token);
        // Refresh watchlist to ensure UI updates
        try {
          final decoded = JwtDecoder.decode(token);
          final rawId = decoded['userId'] ?? decoded['id'] ?? decoded['nameid'] ?? decoded['sub'];
          int? userId;
          if (rawId is int) {
            userId = rawId;
          } else if (rawId is String) {
            userId = int.tryParse(rawId);
          }
          if (userId != null) {
            await watchlistProvider.loadUserWatchlists(userId);
          }
        } catch (_) {
          // Silently fail
        }
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${_series.title} removed from watchlist'),
              backgroundColor: AppColors.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
          setState(() {}); // Refresh UI
        }
      } else {
        // Add to watchlist
        await watchlistProvider.addToWatchlist(widget.series.id);
        // Refresh watchlist to ensure UI updates
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final token = authProvider.token;
        if (token != null && token.isNotEmpty) {
          try {
            final decoded = JwtDecoder.decode(token);
            final rawId = decoded['userId'] ?? decoded['id'] ?? decoded['nameid'] ?? decoded['sub'];
            int? userId;
            if (rawId is int) {
              userId = rawId;
            } else if (rawId is String) {
              userId = int.tryParse(rawId);
            }
            if (userId != null) {
              await watchlistProvider.loadUserWatchlists(userId);
            }
          } catch (_) {
            // Silently fail
          }
        }
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${_series.title} added to watchlist'),
              backgroundColor: AppColors.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
          setState(() {}); // Refresh UI
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.dangerColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildBanner(context),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppDim.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _series.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: AppDim.paddingSmall),

                  // Release year and season/episode info with heart icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${_series.releaseDate.year}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (_series.seasons.isNotEmpty) ...[
                            const SizedBox(width: AppDim.paddingSmall),
                            Text(
                              '• ${_series.totalSeasons} season${_series.totalSeasons > 1 ? 's' : ''}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: AppDim.paddingSmall),
                            Text(
                              '• ${_series.totalEpisodes} episodes',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Heart icon positioned like in prototype
                      Consumer<WatchlistProvider>(
                        builder: (context, watchlistProvider, child) {
                          return FutureBuilder<bool>(
                            key: ValueKey(_favoriteRebuildKey), // Force rebuild when key changes
                            future: watchlistProvider.isInFavorites(_series.id),
                            builder: (context, snapshot) {
                              final isFavorite = snapshot.data ?? false;
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: IconButton(
                                  key: ValueKey(isFavorite),
                                  icon: Icon(
                                    isFavorite ? Icons.favorite : Icons.favorite_border,
                                    color: isFavorite ? Colors.red : AppColors.textSecondary,
                                    size: 28,
                                  ),
                                  onPressed: () async {
                                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                    if (!authProvider.isAuthenticated) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Please log in to add favorites'),
                                            backgroundColor: AppColors.dangerColor,
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                    
                                    try {
                                      await watchlistProvider.toggleFavorites(_series.id);
                                      if (mounted) {
                                        // Small delay to ensure backend has processed the change
                                        await Future.delayed(const Duration(milliseconds: 100));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isFavorite 
                                                ? 'Removed from favorites' 
                                                : 'Added to favorites',
                                            ),
                                            backgroundColor: AppColors.successColor,
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                        // Refresh the screen state to force FutureBuilder to rebuild
                                        setState(() {
                                          _favoriteRebuildKey++; // Change key to force FutureBuilder rebuild
                                        });
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: AppColors.dangerColor,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDim.paddingSmall),

                  // Genres as Chips
                  if (_series.genres.isNotEmpty)
                    Wrap(
                      spacing: AppDim.paddingSmall,
                      runSpacing: AppDim.paddingSmall,
                      children: _series.genres.map((genre) {
                        return Chip(
                          label: Text(
                            genre,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                          labelStyle: const TextStyle(
                            color: AppColors.primaryColor,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDim.paddingSmall,
                            vertical: 4,
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: AppDim.paddingMedium),

                  // Rating Display
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDim.paddingMedium,
                          vertical: AppDim.paddingSmall,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: AppColors.textLight,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _series.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDim.paddingMedium),
                      if (_series.ratingsCount > 0)
                        Text(
                          '(${_series.ratingsCount} reviews)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: AppDim.paddingMedium),

                  // Rate this series section
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      if (!authProvider.isAuthenticated) {
                        return const SizedBox.shrink();
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rate this series',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppDim.paddingSmall),
                          Row(
                            children: List.generate(5, (index) {
                              final rating = index + 1;
                              final isSelected = _userRating != null && rating <= _userRating!;
                              
                              return GestureDetector(
                                onTap: _isRatingLoading ? null : () => _handleRatingTap(rating),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    isSelected ? Icons.star : Icons.star_border,
                                    color: isSelected ? Colors.amber : AppColors.textSecondary,
                                    size: 32,
                                  ),
                                ),
                              );
                            }),
                          ),
                          if (_isRatingLoading)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: AppDim.paddingLarge),

                  // Progress Section
                  Consumer<EpisodeProgressProvider>(
                    builder: (context, progressProvider, child) {
                      // Use cached future - it's initialized in initState()
                      // If future is null, use cached data from provider to avoid notifyListeners during build
                      final cachedProgress = progressProvider.getSeriesProgress(_series.id);
                      
                      return FutureBuilder<SeriesProgress?>(
                        future: _progressFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 100,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          
                          final progress = snapshot.data ?? progressProvider.getSeriesProgress(_series.id);
                          
                          // Calculate progress for selected season if available
                          int totalEpisodes = progress?.totalEpisodes ?? _series.totalEpisodes;
                          int currentEpisode = progress?.currentEpisodeNumber ?? 0;
                          double progressPercentage = progress?.progressPercentage ?? 0.0;
                          
                          // If a season is selected and seasons are loaded, show season-specific progress
                          final selectedSeason = _selectedSeason;
                          if (selectedSeason != null && _series.seasons.isNotEmpty && selectedSeason.episodes.isNotEmpty) {
                            final seasonEpisodes = selectedSeason.episodes;
                            final watchedInSeason = _watchedEpisodeIds
                                .where((epId) => seasonEpisodes.any((e) => e.id == epId))
                                .length;
                            totalEpisodes = seasonEpisodes.length;
                            currentEpisode = watchedInSeason;
                            progressPercentage = totalEpisodes > 0 
                                ? (watchedInSeason / totalEpisodes * 100) 
                                : 0.0;
                          } else if (totalEpisodes == 0 && _series.seasons.isNotEmpty) {
                            // If no progress but seasons exist, calculate from seasons
                            totalEpisodes = _series.totalEpisodes;
                            currentEpisode = 0;
                            progressPercentage = 0.0;
                          }
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Your Progress',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _showMarkEpisodesDialog(
                                      context,
                                      progressProvider,
                                      totalEpisodes,
                                      currentEpisode,
                                      selectedSeason: selectedSeason,
                                    ),
                                    icon: const Icon(Icons.check_circle_outline, size: 20),
                                    label: const Text('Mark Episodes'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDim.paddingSmall),
                              // Always show progress bar
                              Text(
                                _selectedSeason != null && _series.seasons.isNotEmpty
                                    ? 'Season ${_selectedSeason!.seasonNumber}: $currentEpisode of $totalEpisodes episodes'
                                    : totalEpisodes > 0
                                        ? 'Episode $currentEpisode of $totalEpisodes'
                                        : 'Not started',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppDim.paddingSmall),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: totalEpisodes > 0 ? (progressPercentage / 100).clamp(0.0, 1.0) : 0.0,
                                  minHeight: 8,
                                  backgroundColor: AppColors.primaryColor.withOpacity(0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    totalEpisodes > 0 
                                        ? AppColors.primaryColor 
                                        : AppColors.primaryColor.withOpacity(0.3),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalEpisodes > 0
                                    ? '${progressPercentage.toStringAsFixed(1)}% complete'
                                    : '0% complete',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: AppDim.paddingLarge),

                  // Seasons and Episodes Section
                  if (_series.seasons.isNotEmpty) ...[
                    Text(
                      'Seasons & Episodes',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDim.paddingMedium),
                    
                    // Season Selector
                    SeasonSelector(
                      seasons: _series.seasons,
                      selectedSeasonNumber: _selectedSeasonNumber,
                      onSeasonSelected: (seasonNumber) {
                        setState(() {
                          _selectedSeasonNumber = seasonNumber;
                        });
                      },
                    ),
                    
                    const SizedBox(height: AppDim.paddingMedium),
                    
                    // Episodes List for Selected Season
                    if (_selectedSeason != null) ...[
                      _buildEpisodesList(_selectedSeason!, theme),
                    ] else if (_isLoadingDetail) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppDim.paddingLarge),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: AppDim.paddingLarge),
                  ],

                  // Description with Read more (SHORT - 2-3 lines only)
                  if (_series.description != null && _series.description!.isNotEmpty) ...[
                    Text(
                      'Description',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDescription(_series.description!, theme),
                    const SizedBox(height: AppDim.paddingLarge),
                  ],

                  // Actors Section
                  if (_series.actors.isNotEmpty) ...[
                    Text(
                      'Cast',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDim.paddingMedium),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
                        itemCount: _series.actors.length,
                        itemBuilder: (context, index) {
                          final actor = _series.actors[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: AppDim.paddingSmall),
                            child: _buildActorCard(actor, context, theme),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppDim.paddingLarge),
                  ],

                  const SizedBox(height: AppDim.paddingMedium),

                  // Add to list button
                  Consumer<WatchlistProvider>(
                    builder: (context, watchlistProvider, child) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddToListDialog(context, _series),
                          icon: const Icon(Icons.add),
                          label: const Text(
                            'Add to list',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: AppColors.textLight,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppDim.paddingMedium,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                            ),
                            elevation: 4,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: AppDim.paddingLarge),

                  // Reviews Section
                  Text(
                    'Reviews',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDim.paddingMedium),
                  
                  // Reviews preview (2-3 reviews)
                  _buildReviewsPreview(context, theme),
                  
                  const SizedBox(height: AppDim.paddingMedium),
                  
                  // See all reviews button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MobilePageRoute(
                            builder: (context) => MobileReviewsScreen(series: _series),
                          ),
                        );
                        // Refresh reviews if a review was added/edited/deleted
                        if (result == true && mounted) {
                          final ratingProvider = Provider.of<RatingProvider>(context, listen: false);
                          await ratingProvider.loadSeriesRatings(_series.id);
                          // Refresh series detail to update rating count
                          final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
                          await seriesProvider.fetchSeriesDetail(_series.id);
                          // Update local series data
                          final updated = seriesProvider.getById(_series.id);
                          if (updated != null) {
                            setState(() {
                              _series = updated;
                            });
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryColor,
                        side: BorderSide(color: AppColors.primaryColor),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDim.paddingMedium,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                        ),
                      ),
                      child: const Text('See all reviews'),
                    ),
                  ),

                  const SizedBox(height: AppDim.paddingLarge),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the banner image
  Widget _buildBanner(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Series Image
        ImageWithPlaceholder(
          imageUrl: _series.imageUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          placeholderIcon: Icons.movie,
          placeholderIconSize: 80,
          placeholderBackgroundColor: AppColors.primaryColor,
        ),
        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.3),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds an actor card for horizontal list
  Widget _buildActorCard(Actor actor, BuildContext context, ThemeData theme) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: AppDim.paddingMedium),
      child: Column(
        children: [
          // Actor Avatar with image
          ImageWithPlaceholder(
            imageUrl: actor.imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            isCircular: true,
            radius: 30,
            placeholderIcon: Icons.person,
            placeholderIconSize: 30,
          ),
          const SizedBox(height: AppDim.paddingSmall),
          // Actor Name
          Text(
            actor.fullName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsPreview(BuildContext context, ThemeData theme) {
    return Consumer<RatingProvider>(
      builder: (context, ratingProvider, child) {
        final reviews = ratingProvider.getSeriesRatings(_series.id);
        final previewReviews = reviews.take(2).toList();

        if (previewReviews.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDim.paddingMedium),
            child: Text(
              'No reviews yet. Be the first to review!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }

        return Column(
          children: previewReviews.map((review) {
            return Card(
              margin: const EdgeInsets.only(bottom: AppDim.paddingSmall),
              child: ListTile(
                title: Text(
                  review.userName ?? 'Anonymous',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < review.starRating
                              ? Icons.star
                              : Icons.star_border,
                          size: 16,
                          color: Colors.amber,
                        );
                      }),
                    ),
                    if (review.comment != null && review.comment!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        review.comment!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Build episodes list for a season
  Widget _buildEpisodesList(Season season, ThemeData theme) {
    if (season.episodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppDim.paddingMedium),
        child: Text(
          'No episodes available for this season.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Sort episodes by episode number
    final sortedEpisodes = List<Episode>.from(season.episodes)
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Season ${season.seasonNumber} • ${season.episodes.length} episodes',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppDim.paddingMedium),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedEpisodes.length,
          itemBuilder: (context, index) {
            final episode = sortedEpisodes[index];
            return _buildEpisodeCard(episode, season, theme);
          },
        ),
      ],
    );
  }

  /// Build a single episode card
  Widget _buildEpisodeCard(Episode episode, Season season, ThemeData theme) {
    final isWatched = _watchedEpisodeIds.contains(episode.id);
    final episodeNumber = 'S${season.seasonNumber.toString().padLeft(2, '0')}E${episode.episodeNumber.toString().padLeft(2, '0')}';
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppDim.paddingSmall),
      color: isWatched 
          ? AppColors.primaryColor.withOpacity(0.1) 
          : AppColors.cardBackground,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isWatched 
              ? AppColors.successColor 
              : AppColors.primaryColor,
          child: Text(
            episodeNumber,
            style: TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                episode.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isWatched)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.check_circle,
                  size: 20,
                  color: AppColors.successColor,
                ),
              ),
          ],
        ),
        subtitle: episode.description != null && episode.description!.isNotEmpty
            ? Text(
                episode.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            : episode.airDate != null
                ? Text(
                    'Aired: ${episode.airDate!.year}-${episode.airDate!.month.toString().padLeft(2, '0')}-${episode.airDate!.day.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                : null,
        trailing: episode.rating != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    size: 16,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    episode.rating!.toStringAsFixed(1),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )
            : IconButton(
                icon: Icon(
                  isWatched ? Icons.check_circle : Icons.check_circle_outline,
                  color: isWatched ? AppColors.successColor : AppColors.textSecondary,
                ),
                onPressed: () => _toggleEpisodeWatched(episode.id, isWatched),
                tooltip: isWatched ? 'Mark as unwatched' : 'Mark as watched',
              ),
        onTap: () => _toggleEpisodeWatched(episode.id, isWatched),
      ),
    );
  }

  /// Toggle episode watched status
  Future<void> _toggleEpisodeWatched(int episodeId, bool isCurrentlyWatched) async {
    try {
      final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
      
      if (isCurrentlyWatched) {
        // Mark as unwatched (remove progress)
        await progressProvider.removeProgress(episodeId);
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _watchedEpisodeIds.remove(episodeId);
              });
            }
          });
        }
      } else {
        // Mark as watched - explicitly set isCompleted to true
        await progressProvider.markEpisodeWatched(episodeId, isCompleted: true);
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _watchedEpisodeIds.add(episodeId);
              });
            }
          });
        }
      }
      
      // Refresh series progress and watched episodes
      _progressFuture = progressProvider.loadSeriesProgress(_series.id);
      await _progressFuture;
      await _loadWatchedEpisodes();
      
      // Refresh series detail to get any new episodes that might have been added
      await _loadSeriesDetail();
      
      // Small delay to ensure watched episodes list is updated
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (mounted) {
        // Use post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (mounted) {
            // Reload watched episodes to ensure persistence
            await _loadWatchedEpisodes();
            
            // Reload progress to ensure it's synced with backend
            final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
            await progressProvider.loadSeriesProgress(_series.id);
            
            // Check if all episodes are now watched (only if we marked as watched, not unwatched)
            if (!isCurrentlyWatched) {
              // Use backend's calculated progress to check completion (more reliable)
              // Backend sums episodes across ALL seasons correctly
              final progress = progressProvider.getSeriesProgress(_series.id);
              final isComplete = progress != null && 
                                 progress.totalEpisodes > 0 && 
                                 progress.watchedEpisodes >= progress.totalEpisodes;
              
              if (isComplete) {
                // Series is complete - refresh challenges and notify everything
                await _refreshOnSeriesCompletion();
                _showCompletionNotification();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Episode marked as watched!'),
                    backgroundColor: AppColors.successColor,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Episode marked as unwatched'),
                  backgroundColor: AppColors.successColor,
                  duration: Duration(seconds: 2),
                ),
              );
              // Also refresh if unwatching might change completion status
              final progress = progressProvider.getSeriesProgress(_series.id);
              if (progress != null && progress.totalEpisodes > 0 && progress.watchedEpisodes < progress.totalEpisodes) {
                // Series no longer complete - refresh challenges too
                try {
                  final challengesProvider = Provider.of<MobileChallengesProvider>(context, listen: false);
                  await challengesProvider.fetchMyProgress();
                } catch (_) {
                  // Silently fail
                }
              }
            }
            setState(() {}); // Refresh UI
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating episode: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  Widget _buildDescription(String description, ThemeData theme) {
    // Show only 2-3 lines (approximately 100-120 characters)
    const maxLength = 120;
    final isLong = description.length > maxLength;
    
    if (!isLong) {
      // If description is short, show it with a "Read more" button below
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDim.paddingSmall),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MobilePageRoute(
                  builder: (context) => MobileSeriesDescriptionScreen(series: _series),
                ),
              );
            },
            child: const Text(
              'Read more',
              style: TextStyle(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );
    }
    
    // For long descriptions, show 2-3 lines with "Read more" button below
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppDim.paddingSmall),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MobilePageRoute(
                builder: (context) => MobileSeriesDescriptionScreen(series: _series),
              ),
            );
          },
          child: const Text(
            'Read more',
            style: TextStyle(
              color: AppColors.primaryColor,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleRatingTap(int rating) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final ratingProvider = Provider.of<RatingProvider>(context, listen: false);
    final token = authProvider.token;
    
    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to rate series'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
      return;
    }

    setState(() {
      _isRatingLoading = true;
      _userRating = rating;
    });

    try {
      // Convert star rating (1-5) to score (1-10)
      final score = rating * 2;
      
      await ratingProvider.createOrUpdateRating(
        seriesId: _series.id,
        score: score,
        comment: null, // Just rating, no comment
      );
      
      // Refresh reviews to show updated rating
      await ratingProvider.loadSeriesRatings(_series.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You rated this series ${rating} star${rating > 1 ? 's' : ''}'),
            backgroundColor: AppColors.successColor,
          ),
        );
        setState(() {}); // Refresh UI
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userRating = null;
        });
        
        // Check if the error is about needing to finish the series
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('finish') && errorMessage.contains('series')) {
          // Friendly notification for this specific case
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Watch all episodes to rate this series',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.infoColor,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          // Generic error for other cases
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit rating: ${e.toString().replaceAll('ApiException: ', '')}'),
              backgroundColor: AppColors.dangerColor,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRatingLoading = false;
        });
      }
    }
  }

  /// Load full series detail with seasons and episodes
  Future<void> _loadSeriesDetail() async {
    if (_isLoadingDetail) return;
    
    setState(() {
      _isLoadingDetail = true;
    });

    try {
      final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
      final detail = await seriesProvider.fetchSeriesDetail(_series.id);
      
      if (detail != null && mounted) {
        // Use post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _series = detail;
              // Auto-select first season if available and none selected
              if (_series.seasons.isNotEmpty && _selectedSeasonNumber == null) {
                final sortedSeasons = List<Season>.from(_series.seasons)
                  ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
                _selectedSeasonNumber = sortedSeasons.first.seasonNumber;
              }
              _isLoadingDetail = false;
            });
            // Reload watched episodes after series detail loads
            _loadWatchedEpisodes();
            // Reset progress future to reload with new series data
            _progressFuture = null;
          }
        });
      } else if (mounted) {
        setState(() {
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDetail = false;
        });
      }
    }
  }

  /// Load progress for the series
  Future<SeriesProgress?> _loadProgress(EpisodeProgressProvider provider) async {
    try {
      return await provider.loadSeriesProgress(_series.id);
    } catch (e) {
      // Return cached progress if available, or null if not found
      return provider.getSeriesProgress(_series.id);
    }
  }

  /// Refresh everything when a series is completed
  Future<void> _refreshOnSeriesCompletion() async {
    try {
      // Refresh challenges if user has started any
      try {
        final challengesProvider = Provider.of<MobileChallengesProvider>(context, listen: false);
        await challengesProvider.fetchMyProgress();
      } catch (e) {
        // Don't fail - challenges update is optional
      }
      
      // Clear progress cache to force fresh reload
      final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
      progressProvider.clearProgressCache(_series.id);
      
      // Reload progress for this series with fresh data
      await progressProvider.loadSeriesProgress(_series.id);
    } catch (e) {
      // Don't throw - refresh is best effort
    }
  }

  /// Check if all episodes across all seasons are watched
  Future<bool> _checkIfSeriesComplete() async {
    try {
      // Ensure series detail is loaded with seasons
      if (_series.seasons.isEmpty) {
        return false;
      }

      // Get all episode IDs from all seasons
      final allEpisodeIds = <int>{};
      for (var season in _series.seasons) {
        for (var episode in season.episodes) {
          allEpisodeIds.add(episode.id);
        }
      }

      if (allEpisodeIds.isEmpty) {
        return false;
      }

      // Check if all episodes are in watched list
      return allEpisodeIds.every((epId) => _watchedEpisodeIds.contains(epId));
    } catch (e) {
      return false;
    }
  }

  /// Show completion notification with option to rate
  void _showCompletionNotification() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🎉 Series Complete!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You\'ve finished ${_series.title}. Rate it now!',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryColor,
        duration: const Duration(seconds: 3), // Auto-dismiss after 3 seconds
        action: SnackBarAction(
          label: 'Rate',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MobilePageRoute(
                builder: (context) => MobileReviewsScreen(series: _series),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Load watched episode IDs for UI indicators
  Future<void> _loadWatchedEpisodes() async {
    if (!mounted) return;
    
    try {
      final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      if (token == null || token.isEmpty) {
        return;
      }

      // Always reload progress for this series to ensure we have the latest data from backend
      // Don't rely on cache as it might be stale after leaving a review or completing series
      await progressProvider.loadSeriesProgress(_series.id);

      // Use getUserProgress to get all watched episodes for accurate data
      final progressService = EpisodeProgressService();
      final userProgress = await progressService.getUserProgress(token: token);
      
      // Update watched episodes immediately (filter for completed episodes only)
      if (mounted) {
        final newWatchedIds = userProgress
            .where((p) => p.seriesId == _series.id && p.isCompleted)
            .map((p) => p.episodeId)
            .toSet();
        
        // Always update to ensure we have the latest data from backend
          setState(() {
            _watchedEpisodeIds = newWatchedIds;
          });
      }
    } catch (e) {
      // Silently fail - watched indicators just won't show
      // But try to use cached progress as fallback
      try {
        final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
        final progress = progressProvider.getSeriesProgress(_series.id);
        if (progress != null && mounted) {
          // If we have progress but couldn't load watched episodes,
          // at least ensure we don't lose the progress data
          // Watched episodes will be empty, but progress will still show
        }
      } catch (_) {
        // Silently fail
      }
    }
  }

  /// Get the currently selected season
  Season? get _selectedSeason {
    if (_selectedSeasonNumber == null || _series.seasons.isEmpty) return null;
    try {
      return _series.seasons.firstWhere(
        (s) => s.seasonNumber == _selectedSeasonNumber,
      );
    } catch (e) {
      return null;
    }
  }

  /// Show dialog to mark episodes as watched
  Future<void> _showMarkEpisodesDialog(
    BuildContext context,
    EpisodeProgressProvider progressProvider,
    int totalEpisodes,
    int currentEpisode, {
    Season? selectedSeason,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to track progress'),
          backgroundColor: AppColors.dangerColor,
        ),
      );
      return;
    }

    // Ensure totalEpisodes is valid (at least 1)
    if (totalEpisodes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No episodes available to mark'),
          backgroundColor: AppColors.dangerColor,
        ),
      );
      return;
    }

    final result = await showDialog<int>(
      context: context,
      builder: (context) => MarkEpisodesDialog(
        totalEpisodes: totalEpisodes,
        currentEpisode: currentEpisode,
        seriesTitle: _series.title,
      ),
    );

    if (result != null && mounted) {
      // Mark episodes sequentially up to the selected number
      // Pass the selected season so we can mark season-specific episodes
      await _markEpisodesUpTo(progressProvider, result, selectedSeason: selectedSeason);
    }
  }

  /// Mark episodes sequentially up to a certain episode number
  /// If selectedSeason is provided, marks episodes in that season up to the target episode number within that season
  Future<void> _markEpisodesUpTo(
    EpisodeProgressProvider progressProvider,
    int targetEpisode, {
    Season? selectedSeason,
  }) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marking episodes...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Refresh watched episodes list BEFORE marking to ensure we have the latest state
      // Do this synchronously by directly fetching and updating
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      if (token != null && token.isNotEmpty) {
        try {
          final progressService = EpisodeProgressService();
          final userProgress = await progressService.getUserProgress(token: token);
          if (mounted) {
            setState(() {
              _watchedEpisodeIds = userProgress
                  .where((p) => p.seriesId == _series.id && p.isCompleted)
                  .map((p) => p.episodeId)
                  .toSet();
            });
          }
        } catch (e) {
          // If refresh fails, continue with current state
        }
      }

      int episodesToMark = 0;
      
      // If a season is selected, we need to mark episodes specifically in that season
      if (selectedSeason != null && selectedSeason.episodes.isNotEmpty) {
        // Get all episodes in this season, sorted by episode number
        // Then take first N unwatched episodes (not based on episode number, but position)
        // This handles cases where episodes don't start from 1 (e.g., episodes 3, 4, 5, 6)
        final allEpisodesSorted = selectedSeason.episodes.toList()
          ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
        
        // Filter to only unwatched episodes, then take first N
        final unwatchedEpisodes = allEpisodesSorted
            .where((ep) => !_watchedEpisodeIds.contains(ep.id))
            .toList();
        
        // Take first targetEpisode number of unwatched episodes
        final episodesToMarkList = unwatchedEpisodes.take(targetEpisode).toList();
        
        if (episodesToMarkList.isEmpty) {
          if (mounted) {
            // Check if all episodes up to target are already watched
            // First, get all episode numbers that should exist (1 to targetEpisode)
            final expectedEpisodeNumbers = List.generate(targetEpisode, (i) => i + 1);
            
            // Get actual episodes that exist in the season
            final existingEpisodesUpToTarget = selectedSeason.episodes
                .where((ep) => ep.episodeNumber <= targetEpisode)
                .toList();
            
            // Check if there are gaps (missing episodes)
            final existingEpisodeNumbers = existingEpisodesUpToTarget
                .map((ep) => ep.episodeNumber)
                .toSet();
            final missingEpisodes = expectedEpisodeNumbers
                .where((num) => !existingEpisodeNumbers.contains(num))
                .toList();
            
            // Count watched episodes
            final watchedUpToTarget = existingEpisodesUpToTarget
                .where((ep) => _watchedEpisodeIds.contains(ep.id))
                .length;
            
            // Only show "all marked" message if:
            // 1. All existing episodes up to target are watched, AND
            // 2. There are no missing episodes (or we account for them)
            final allExistingWatched = watchedUpToTarget == existingEpisodesUpToTarget.length;
            
            String message;
            if (missingEpisodes.isNotEmpty) {
              // There are missing episodes - be more specific
              message = 'All available episodes up to episode $targetEpisode are marked. '
                  'Note: Episodes ${missingEpisodes.join(", ")} are missing.';
            } else if (allExistingWatched) {
              // All episodes exist and are watched
              message = 'All episodes up to episode $targetEpisode are already marked';
            } else {
              // Some episodes exist but aren't watched
              message = 'No episodes to mark';
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: AppColors.infoColor,
                duration: missingEpisodes.isNotEmpty 
                    ? const Duration(seconds: 5) 
                    : const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
        
        // Mark all episodes in the list
        int markedCount = 0;
        final List<int> newlyMarkedIds = [];
        
        for (final episode in episodesToMarkList) {
          try {
            await progressProvider.markEpisodeWatched(episode.id, isCompleted: true);
            newlyMarkedIds.add(episode.id);
            markedCount++;
          } catch (e) {
            // Continue with other episodes
          }
        }
        
        // Update watched episode IDs in one setState call
        if (newlyMarkedIds.isNotEmpty && mounted) {
          setState(() {
            _watchedEpisodeIds.addAll(newlyMarkedIds);
          });
        }
        
        episodesToMark = markedCount;
      } else {
        // No season selected - mark series-wide (original behavior)
        final currentProgress = progressProvider.getSeriesProgress(_series.id);
        final currentEpisode = currentProgress?.currentEpisodeNumber ?? 0;
        
        episodesToMark = targetEpisode - currentEpisode;
        if (episodesToMark <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No new episodes to mark'),
                backgroundColor: AppColors.infoColor,
              ),
            );
          }
          return;
        }

        // Mark episodes one by one using the next episode API
        int markedCount = 0;
        final List<int> newlyMarkedIds = [];
        
        for (int i = 0; i < episodesToMark; i++) {
          final nextEpisodeData = await progressProvider.getNextEpisodeId(_series.id);
          if (nextEpisodeData != null) {
            // Explicitly mark as completed
            await progressProvider.markEpisodeWatched(nextEpisodeData, isCompleted: true);
            newlyMarkedIds.add(nextEpisodeData);
            markedCount++;
          } else {
            // No more episodes to mark
            break;
          }
        }
        
        // Update watched episode IDs in one setState call
        if (newlyMarkedIds.isNotEmpty && mounted) {
          setState(() {
            _watchedEpisodeIds.addAll(newlyMarkedIds);
          });
        }
        
        episodesToMark = markedCount;
      }

      // Refresh progress and watched episodes from server to ensure consistency
      await progressProvider.loadSeriesProgress(_series.id);
      await _loadWatchedEpisodes();
      
      // Small delay to ensure watched episodes list is fully updated
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        // Check if all episodes are now watched
        final isComplete = await _checkIfSeriesComplete();
        
        if (isComplete) {
          _showCompletionNotification();
        } else if (episodesToMark > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Marked ${episodesToMark} episode${episodesToMark > 1 ? 's' : ''} as watched!'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
        // Refresh the UI
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking episodes: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _showAddToListDialog(BuildContext context, Series series) async {
    final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to add series to lists'),
          backgroundColor: AppColors.dangerColor,
        ),
      );
      return;
    }

    // Always reload user's lists to ensure we have the latest data
    // This prevents issues with stale cache from previous users or deleted lists
    try {
      final decoded = JwtDecoder.decode(token);
      final rawId = decoded['userId'] ?? decoded['id'] ?? decoded['nameid'] ?? decoded['sub'];
      int? userId;
      if (rawId is int) {
        userId = rawId;
      } else if (rawId is String) {
        userId = int.tryParse(rawId);
      }
      
      if (userId != null) {
        await watchlistProvider.loadUserWatchlists(userId);
      }
    } catch (_) {
      // Silently fail
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _WatchlistSelector(seriesId: series.id),
    );
  }
}

class _WatchlistSelector extends StatefulWidget {
  final int? seriesId;

  const _WatchlistSelector({super.key, required this.seriesId});

  @override
  State<_WatchlistSelector> createState() => _WatchlistSelectorState();
}

class _WatchlistSelectorState extends State<_WatchlistSelector> {
  int? _processingListId;
  Map<int, bool> _seriesInList = {}; // Cache for checking if series is in each list

  @override
  void initState() {
    super.initState();
    _checkSeriesInLists();
  }

  Future<void> _checkSeriesInLists() async {
    final seriesId = widget.seriesId;
    if (seriesId == null) return;

    final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    
    if (token == null) return;

    try {
      final decoded = JwtDecoder.decode(token);
      final rawId = decoded['userId'] ?? decoded['id'] ?? decoded['nameid'] ?? decoded['sub'];
      int? userId;
      if (rawId is int) {
        userId = rawId;
      } else if (rawId is String) {
        userId = int.tryParse(rawId);
      }
      if (userId == null) return;

      // Check each list to see if series is already in it
      for (final list in watchlistProvider.lists) {
        try {
          final collectionData = await watchlistProvider.service?.getWatchlistCollection(
            list.id,
            token: token,
          );
          final watchlists = collectionData?['watchlists'] as List?;
          final isInList = watchlists != null && watchlists.any((w) {
            if (w is Map<String, dynamic>) {
              final series = w['series'] as Map<String, dynamic>?;
              return series != null && series['id'] == seriesId;
            }
            return false;
          });
          _seriesInList[list.id] = isInList ?? false;
        } catch (_) {
          _seriesInList[list.id] = false;
        }
      }
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Silently fail
    }
  }

  @override
  Widget build(BuildContext context) {
    final seriesId = widget.seriesId;

    if (seriesId == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Invalid series.'),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Consumer<WatchlistProvider>(
          builder: (context, provider, child) {
            final lists = provider.lists;

            if (provider.loading && lists.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (lists.isEmpty) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'You have no lists yet.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/create_list');
                    },
                    child: const Text('Create a new list'),
                  ),
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Add to list',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: lists.length,
                    itemBuilder: (context, index) {
                      final list = lists[index];
                      final isProcessing = _processingListId == list.id;
                      final isAlreadyInList = _seriesInList[list.id] ?? false;
                      final seriesCount = list.totalSeries;
                      // Always show series count, even if 0
                      final seriesText = seriesCount == 1 
                          ? '1 series' 
                          : seriesCount == 0 
                              ? '0 series'
                              : '$seriesCount series';

                      return ListTile(
                        title: Text(list.name),
                        subtitle: Text(
                          seriesText,
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : isAlreadyInList
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 24,
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () async {
                                      setState(() {
                                        _processingListId = list.id;
                                      });
                                      try {
                                        final watchlistProvider = Provider.of<WatchlistProvider>(
                                          context,
                                          listen: false,
                                        );
                                        await watchlistProvider.addSeries(list.id, seriesId);
                                        
                                        // Refresh watchlist to show immediately
                                        try {
                                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                          final decoded = JwtDecoder.decode(authProvider.token!);
                                          final rawId = decoded['userId'] ?? decoded['id'] ?? decoded['nameid'] ?? decoded['sub'];
                                          int? userId;
                                          if (rawId is int) {
                                            userId = rawId;
                                          } else if (rawId is String) {
                                            userId = int.tryParse(rawId);
                                          }
                                          if (userId != null) {
                                            await watchlistProvider.loadUserWatchlists(userId);
                                            // Recheck which lists contain this series
                                            await _checkSeriesInLists();
                                          }
                                        } catch (_) {
                                          // Silently fail - refresh is optional
                                        }

                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.check_circle, color: Colors.white),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text('Added to "${list.name}"'),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: Colors.green,
                                              duration: const Duration(seconds: 2),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                          Navigator.pop(context);
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          final errorMessage = e.toString().toLowerCase();
                                          // Check if it's a duplicate error - show friendly notification
                                          if (errorMessage.contains('lista je već dodata') ||
                                              errorMessage.contains('already') || 
                                              errorMessage.contains('series already in this collection') ||
                                              errorMessage.contains('already in this collection')) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(Icons.info_outline, color: Colors.white),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text('Lista je već dodata'),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: Colors.orange,
                                                duration: const Duration(seconds: 3),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(Icons.error_outline, color: Colors.white),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text('Unable to add series. Please try again.'),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: Colors.red,
                                                duration: const Duration(seconds: 3),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _processingListId = null;
                                          });
                                        }
                                      }
                                    },
                                  ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/create_list');
                    },
                    child: const Text('Create a new list'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

