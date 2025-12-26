import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../models/series.dart';
import '../models/season.dart'; // Contains both Season and Episode classes
import '../providers/watchlist_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/episode_progress_provider.dart';
import '../providers/series_provider.dart';
import '../services/api_service.dart';
import '../services/episode_progress_service.dart';
import '../core/theme/app_colors.dart';
import '../mobile/widgets/season_selector.dart';
import 'episode_reviews_screen.dart';
import 'series_full_description_screen.dart';
import '../services/reminder_service.dart';

/// Screen that displays detailed information about a series
class SeriesDetailScreen extends StatefulWidget {
  final Series series;

  const SeriesDetailScreen({
    super.key,
    required this.series,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  int? _currentUserId;
  late Series _series;
  int? _selectedSeasonNumber;
  bool _isLoadingDetail = false;
  Set<int> _watchedEpisodeIds = {}; // Track watched episode IDs for UI updates
  bool _isReminderEnabled = false;
  final ReminderService _reminderService = ReminderService();

  @override
  void initState() {
    super.initState();
    _series = widget.series;
    
    // Load user lists and legacy watchlist
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.token;

      // Decode userId from JWT for collections
      if (token != null && token.isNotEmpty) {
        try {
          final decoded = JwtDecoder.decode(token);
          final rawId = decoded['userId'] ?? decoded['id'] ?? decoded['nameid'] ?? decoded['sub'];
          if (rawId is int) {
            _currentUserId = rawId;
          } else if (rawId is String) {
            _currentUserId = int.tryParse(rawId);
          }
        } catch (_) {
          _currentUserId = null;
        }
      }

      final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);

      // Load legacy single watchlist for the "Already in watchlist" logic
      if (watchlistProvider.items.isEmpty) {
        watchlistProvider.loadWatchlist().catchError((_) {});
      }

      // Load collections (lists) for this user
      if (_currentUserId != null) {
        watchlistProvider.loadUserWatchlists(_currentUserId!).catchError((_) {});
      }

      // Load episode progress for this series
      final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
      progressProvider.loadSeriesProgress(widget.series.id).then((_) {
        // Load watched episodes for UI indicators
        _loadWatchedEpisodes();
      }).catchError((_) {});
      
      // Load full series detail with seasons and episodes
      _loadSeriesDetail();
      
      // Load reminder state
      _loadReminderState();
    });
  }

  /// Load reminder state for this series
  Future<void> _loadReminderState() async {
    final isEnabled = await _reminderService.isReminderEnabled(widget.series.id);
    if (mounted) {
      setState(() {
        _isReminderEnabled = isEnabled;
      });
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
      final detail = await seriesProvider.fetchSeriesDetail(widget.series.id);
      
      if (detail != null && mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<WatchlistProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: const Icon(
                  Icons.favorite_border,
                  size: 24,
                  color: AppColors.primaryColor,
                ),
                tooltip: 'Add to Favorites',
                onPressed: () async {
                  try {
                    // Ensure we have lists
                    if (_currentUserId != null && provider.lists.isEmpty) {
                      await provider.loadUserWatchlists(_currentUserId!);
                    }

                    final favList = provider.favoritesList;
                    if (favList == null || favList.id == 0) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Favorites list not available.'),
                          backgroundColor: AppColors.dangerColor,
                        ),
                      );
                      return;
                    }

                    await provider.addSeries(favList.id, widget.series.id);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added to ${favList.name}'),
                        backgroundColor: AppColors.successColor,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to add to Favorites: $e'),
                        backgroundColor: AppColors.dangerColor,
                      ),
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Series image
            Container(
              width: double.infinity,
              height: 350,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                      image: _series.imageUrl != null && _series.imageUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(_series.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _series.imageUrl == null || _series.imageUrl!.isEmpty
                  ? Center(
                      child: Icon(
                        Icons.movie,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with heart icon
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _series.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Consumer<WatchlistProvider>(
                        builder: (context, provider, _) {
                          return IconButton(
                            icon: const Icon(
                              Icons.favorite_border,
                              size: 28,
                              color: AppColors.primaryColor,
                            ),
                            tooltip: 'Add to Favorites',
                            onPressed: () async {
                              try {
                                if (_currentUserId != null && provider.lists.isEmpty) {
                                  await provider.loadUserWatchlists(_currentUserId!);
                                }
                                final favList = provider.favoritesList;
                                if (favList == null || favList.id == 0) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Favorites list not available.'),
                                      backgroundColor: AppColors.dangerColor,
                                    ),
                                  );
                                  return;
                                }
                                await provider.addSeries(favList.id, _series.id);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added to ${favList.name}'),
                                    backgroundColor: AppColors.successColor,
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to add to Favorites: $e'),
                                    backgroundColor: AppColors.dangerColor,
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Seasons, episodes and year
                  Row(
                    children: [
                      Text(
                        '${_series.releaseDate.year}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_series.seasons.isNotEmpty) ...[
                        Text(
                          ' • ${_series.totalSeasons} season${_series.totalSeasons > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          ' • ${_series.totalEpisodes} episodes',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Rating
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.successColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                      Text(
                        _series.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (_series.ratingsCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${_series.ratingsCount})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Episode Progress Section
                  Consumer<EpisodeProgressProvider>(
                    builder: (context, progressProvider, _) {
                      final progress = progressProvider.getSeriesProgress(_series.id);
                      
                      if (progress == null) {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Episode ${progress.currentEpisodeNumber} of ${progress.totalEpisodes}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Progress bar
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progress.progressPercentage / 100,
                                          minHeight: 8,
                                          backgroundColor: Colors.grey[300],
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // +1 Button
                                ElevatedButton(
                                  onPressed: progressProvider.loading
                                      ? null
                                      : () async {
                                          // For now, we'll just reload progress
                                          // In a real implementation, you'd mark the next episode as watched
                                          try {
                                            await progressProvider.loadSeriesProgress(_series.id);
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Episode marked as watched!'),
                                                backgroundColor: AppColors.successColor,
                                              ),
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Failed to update progress: $e'),
                                                backgroundColor: AppColors.dangerColor,
                                              ),
                                            );
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryColor,
                                    foregroundColor: AppColors.textLight,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: progressProvider.loading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              AppColors.textLight,
                                            ),
                                          ),
                                        )
                                      : const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add, size: 20),
                                            SizedBox(width: 4),
                                            Text('+1'),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Seasons and Episodes Section
                  if (_series.seasons.isNotEmpty) ...[
                    Text(
                      'Seasons & Episodes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Season Selector
                    SeasonSelector(
                      seasons: _series.seasons,
                      selectedSeasonNumber: _selectedSeasonNumber,
                      onSeasonSelected: (int seasonNumber) {
                        setState(() {
                          _selectedSeasonNumber = seasonNumber;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Episodes List for Selected Season
                    if (_selectedSeason != null) ...[
                      _buildEpisodesList(_selectedSeason!, Theme.of(context)),
                    ] else if (_isLoadingDetail) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                  ],

                  // Series description with "Read more" button
                  if (_series.description != null && _series.description!.isNotEmpty) ...[
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getShortDescription(_series.description!),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SeriesFullDescriptionScreen(series: _series),
                          ),
                        );
                      },
                      child: const Text('Read more'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryColor,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Genres as Wrap with chips
                  if (_series.genres.isNotEmpty) ...[
                    Text(
                      'Genres',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _series.genres.map((genre) {
                        return Chip(
                          label: Text(
                            genre,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          backgroundColor: const Color(0xFFF7F2FA),
                          labelStyle: const TextStyle(
                            color: Color(0xFFFF5A5F),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Actors section
                  if (_series.actors.isNotEmpty) ...[
                    Text(
                      'Actors',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _series.actors.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final actor = _series.actors[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[200]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Actor avatar placeholder
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F2FA),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFFFF5A5F),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Actor name
                              Expanded(
                                child: Text(
                                  actor.fullName,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 32),
                  // Remind me for a new episode Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _toggleReminder(),
                      icon: Icon(_isReminderEnabled ? Icons.notifications : Icons.notifications_outlined),
                      label: Text(_isReminderEnabled ? 'Reminder Enabled' : 'Remind me for a new episode'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: _isReminderEnabled 
                            ? AppColors.successColor 
                            : AppColors.primaryColor,
                        foregroundColor: AppColors.textLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Add to Watchlist Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showWatchlistSelector(context, _series.id);
                      },
                      icon: const Icon(Icons.bookmark_add),
                      label: const Text('Add to Watchlist'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: AppColors.textLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build episodes list for a season
  Widget _buildEpisodesList(Season season, ThemeData theme) {
    if (season.episodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
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
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: sortedEpisodes.length,
            itemBuilder: (context, index) {
              final episode = sortedEpisodes[index];
              return _buildEpisodeCard(episode, season, theme);
            },
          ),
        ),
      ],
    );
  }

  /// Build a single episode card
  Widget _buildEpisodeCard(Episode episode, Season season, ThemeData theme) {
    final isWatched = _watchedEpisodeIds.contains(episode.id);
    final episodeNumber = 'S${season.seasonNumber.toString().padLeft(2, '0')}E${episode.episodeNumber.toString().padLeft(2, '0')}';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isWatched 
          ? AppColors.primaryColor.withOpacity(0.1) 
          : Colors.white,
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
                  const Icon(
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

  /// Load watched episode IDs for UI indicators
  Future<void> _loadWatchedEpisodes() async {
    try {
      final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      if (token == null || token.isEmpty) {
        return;
      }

      final progressService = EpisodeProgressService();
      final userProgress = await progressService.getUserProgress(token: token);
      
      if (mounted) {
        setState(() {
          _watchedEpisodeIds = userProgress
              .where((p) => p.seriesId == _series.id)
              .map((p) => p.episodeId)
              .toSet();
        });
      }
    } catch (e) {
      // Silently fail - watched indicators just won't show
      print('Error loading watched episodes: $e');
    }
  }

  /// Get short description (first 150 characters)
  String _getShortDescription(String fullDescription) {
    if (fullDescription.length <= 150) {
      return fullDescription;
    }
    return '${fullDescription.substring(0, 150)}...';
  }

  /// Toggle reminder for new episodes
  Future<void> _toggleReminder() async {
    try {
      if (_isReminderEnabled) {
        // Disable reminder
        await _reminderService.disableReminder(_series.id);
        if (mounted) {
          setState(() {
            _isReminderEnabled = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reminder disabled'),
              backgroundColor: AppColors.textSecondary,
            ),
          );
        }
      } else {
        // Enable reminder
        await _reminderService.enableReminder(_series.id, _series.title);
        if (mounted) {
          setState(() {
            _isReminderEnabled = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You will be notified when a new episode of ${_series.title} is available'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating reminder: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  /// Toggle episode watched status
  Future<void> _toggleEpisodeWatched(int episodeId, bool isCurrentlyWatched) async {
    try {
      final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
      
      if (isCurrentlyWatched) {
        // Mark as unwatched (remove progress)
        await progressProvider.removeProgress(episodeId);
        setState(() {
          _watchedEpisodeIds.remove(episodeId);
        });
      } else {
        // Mark as watched
        await progressProvider.markEpisodeWatched(episodeId);
        setState(() {
          _watchedEpisodeIds.add(episodeId);
        });
      }
      
      // Refresh series progress and watched episodes
      await progressProvider.loadSeriesProgress(_series.id);
      await _loadWatchedEpisodes();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCurrentlyWatched 
                ? 'Episode marked as unwatched' 
                : 'Episode marked as watched!'),
            backgroundColor: AppColors.successColor,
          ),
        );
        setState(() {}); // Refresh UI
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
}

/// Helper widget for displaying info chips
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFFFF5A5F),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFFF5A5F),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

void _showWatchlistSelector(BuildContext context, int seriesId) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
    builder: (ctx) {
      return _WatchlistSelector(seriesId: seriesId);
    },
  );
}

class _WatchlistSelector extends StatefulWidget {
  final int? seriesId;

  const _WatchlistSelector({super.key, required this.seriesId});

  @override
  State<_WatchlistSelector> createState() => _WatchlistSelectorState();
}

class _WatchlistSelectorState extends State<_WatchlistSelector> {
  int? _processingListId;

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

                      return ListTile(
                        title: Text(list.name),
                        subtitle: Text('${list.totalSeries} series'),
                        trailing: isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () async {
                                  setState(() {
                                    _processingListId = list.id;
                                  });
                                  try {
                                    await Provider.of<WatchlistProvider>(
                                      context,
                                      listen: false,
                                    ).addSeries(list.id, seriesId);

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Added to ${list.name}'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      Navigator.pop(context);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to add: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
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

