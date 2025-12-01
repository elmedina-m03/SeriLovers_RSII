import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../models/series.dart';
import '../providers/episode_progress_provider.dart';
import '../providers/episode_review_provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_colors.dart';
import 'episode_reviews_screen.dart';
import 'add_episode_review_screen.dart';

class WatchlistSeriesDetailScreen extends StatefulWidget {
  final Series series;
  final int? watchlistCollectionId;

  const WatchlistSeriesDetailScreen({
    super.key,
    required this.series,
    this.watchlistCollectionId,
  });

  @override
  State<WatchlistSeriesDetailScreen> createState() => _WatchlistSeriesDetailScreenState();
}

class _WatchlistSeriesDetailScreenState extends State<WatchlistSeriesDetailScreen> {
  int? _currentUserId;
  int _currentEpisode = 0;
  int _totalEpisodes = 0;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;

    if (token != null && token.isNotEmpty) {
      try {
        // Decode userId from JWT
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

    final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
    try {
      final progress = await progressProvider.loadSeriesProgress(widget.series.id);
      setState(() {
        _currentEpisode = progress.currentEpisodeNumber;
        _totalEpisodes = progress.totalEpisodes;
        _isFinished = progress.watchedEpisodes >= progress.totalEpisodes;
      });
    } catch (_) {
      // If no progress, set defaults
      setState(() {
        _currentEpisode = 0;
        _totalEpisodes = 20; // Default fallback - will be updated from progress API
        _isFinished = false;
      });
    }
  }

  Future<void> _incrementEpisode() async {
    if (_currentEpisode >= _totalEpisodes) return;

    final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
    
    try {
      // Get the next episode to mark
      final nextEpisodeId = await progressProvider.getNextEpisodeId(widget.series.id);
      
      if (nextEpisodeId != null) {
        await progressProvider.markEpisodeWatched(nextEpisodeId);
      } else {
        // If no next episode, just increment locally for testing
        setState(() {
          _currentEpisode++;
          if (_currentEpisode >= _totalEpisodes) {
            _isFinished = true;
          }
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All episodes watched!'),
            backgroundColor: AppColors.successColor,
          ),
        );
        return;
      }

      // Reload progress to get updated state
      final progress = await progressProvider.loadSeriesProgress(widget.series.id);
      
      setState(() {
        _currentEpisode = progress.currentEpisodeNumber;
        _totalEpisodes = progress.totalEpisodes;
        _isFinished = progress.watchedEpisodes >= progress.totalEpisodes;
      });

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
          content: Text('Failed to update: $e'),
          backgroundColor: AppColors.dangerColor,
        ),
      );
    }
  }

  Future<void> _decrementEpisode() async {
    if (_currentEpisode <= 0) return;

    final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
    
    try {
      // Get the last watched episode ID and remove it
      final lastEpisodeId = await progressProvider.getLastWatchedEpisodeId(widget.series.id);
      
      if (lastEpisodeId != null) {
        await progressProvider.removeProgress(lastEpisodeId);
      }

      // Reload progress to get updated state
      final progress = await progressProvider.loadSeriesProgress(widget.series.id);
      
      setState(() {
        _currentEpisode = progress.currentEpisodeNumber;
        _totalEpisodes = progress.totalEpisodes;
        _isFinished = progress.watchedEpisodes >= progress.totalEpisodes;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Episode progress updated'),
          backgroundColor: AppColors.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: AppColors.dangerColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressPercentage = _totalEpisodes > 0 
        ? (_currentEpisode / _totalEpisodes).clamp(0.0, 1.0) 
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.series.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                image: widget.series.imageUrl != null && widget.series.imageUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(widget.series.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: widget.series.imageUrl == null || widget.series.imageUrl!.isEmpty
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
                  // Title and episodes
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.series.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_totalEpisodes episodes',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Heart icon
                      IconButton(
                        icon: const Icon(
                          Icons.favorite_border,
                          color: AppColors.primaryColor,
                          size: 28,
                        ),
                        onPressed: () {
                          // Already in watchlist
                        },
                      ),
                      Text(
                        '${widget.series.releaseDate.year}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Rating
                  Row(
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          final rating = widget.series.rating;
                          final filledStars = (rating / 2).round();
                          return Icon(
                            index < filledStars ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 18,
                          );
                        }),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.series.rating.toStringAsFixed(1)} (${widget.series.ratingsCount} reviews)',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Genres
                  if (widget.series.genres.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.series.genres.take(3).map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            genre.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),
                  // Episode Progress Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Episode $_currentEpisode of $_totalEpisodes',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressPercentage,
                            minHeight: 8,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // + and - buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _currentEpisode > 0 ? _decrementEpisode : null,
                              icon: const Icon(Icons.remove_circle_outline),
                              iconSize: 32,
                              color: AppColors.primaryColor,
                              disabledColor: Colors.grey,
                            ),
                            const SizedBox(width: 24),
                            IconButton(
                              onPressed: _currentEpisode < _totalEpisodes ? _incrementEpisode : null,
                              icon: const Icon(Icons.add_circle_outline),
                              iconSize: 32,
                              color: AppColors.primaryColor,
                              disabledColor: Colors.grey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Description
                  if (widget.series.description != null && widget.series.description!.isNotEmpty) ...[
                    Text(
                      widget.series.description!,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        // Show full description
                      },
                      child: const Text(
                        'READ MORE...',
                        style: TextStyle(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Actors section
                  if (widget.series.actors.isNotEmpty) ...[
                    const Text(
                      'Actors',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.series.actors.length,
                        itemBuilder: (context, index) {
                          final actor = widget.series.actors[index];
                          return Container(
                            width: 80,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: AppColors.primaryColor.withOpacity(0.2),
                                  child: const Icon(
                                    Icons.person,
                                    color: AppColors.primaryColor,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  actor.fullName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Mark as Finished button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isFinished
                          ? null
                          : () async {
                              final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
                              
                              try {
                                // Mark all remaining episodes as watched
                                // Get next episode repeatedly until all are watched
                                int marked = 0;
                                for (int i = _currentEpisode; i < _totalEpisodes; i++) {
                                  final nextEpisodeId = await progressProvider.getNextEpisodeId(widget.series.id);
                                  if (nextEpisodeId != null) {
                                    await progressProvider.markEpisodeWatched(nextEpisodeId);
                                    marked++;
                                  } else {
                                    break;
                                  }
                                }

                                // Reload progress
                                final progress = await progressProvider.loadSeriesProgress(widget.series.id);
                                setState(() {
                                  _currentEpisode = progress.currentEpisodeNumber;
                                  _totalEpisodes = progress.totalEpisodes;
                                  _isFinished = progress.watchedEpisodes >= progress.totalEpisodes;
                                });

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(marked > 0 
                                        ? 'Marked $marked episodes as finished!' 
                                        : 'Series already finished!'),
                                    backgroundColor: AppColors.successColor,
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to mark as finished: $e'),
                                    backgroundColor: AppColors.dangerColor,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFinished 
                            ? Colors.grey 
                            : AppColors.primaryColor,
                        foregroundColor: AppColors.textLight,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isFinished ? 'Finished' : 'Mark as Finished',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Reviews Section
                  Consumer<EpisodeProgressProvider>(
                    builder: (context, progressProvider, _) {
                      final progress = progressProvider.getSeriesProgress(widget.series.id);
                      
                      if (progress == null || progress.watchedEpisodes == 0) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.primaryColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Watch episodes to add reviews. Use the + button to track your progress.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Episode Reviews',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  // Get the last watched episode ID
                                  final lastEpisodeId = await progressProvider.getLastWatchedEpisodeId(widget.series.id);
                                  if (lastEpisodeId != null && mounted) {
                                    Navigator.pushNamed(
                                      context,
                                      '/episode_reviews',
                                      arguments: lastEpisodeId,
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('No episodes watched yet'),
                                        backgroundColor: AppColors.dangerColor,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.reviews, size: 18),
                                label: const Text('View All Reviews'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryColor.withOpacity(0.2)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.check_circle, color: AppColors.successColor, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'You\'ve watched ${progress.watchedEpisodes} of ${progress.totalEpisodes} episodes',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      // Get the last watched episode ID
                                      final lastEpisodeId = await progressProvider.getLastWatchedEpisodeId(widget.series.id);
                                      if (lastEpisodeId != null && mounted) {
                                        Navigator.pushNamed(
                                          context,
                                          '/add_episode_review',
                                          arguments: {
                                            'episodeId': lastEpisodeId,
                                            'existingReview': null,
                                          },
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('No episodes watched yet'),
                                            backgroundColor: AppColors.dangerColor,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('Review Last Watched Episode'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryColor,
                                      foregroundColor: AppColors.textLight,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
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
}

