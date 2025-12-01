import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../models/series.dart';
import '../providers/watchlist_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/episode_progress_provider.dart';
import '../services/api_service.dart';
import '../core/theme/app_colors.dart';
import 'episode_reviews_screen.dart';

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

  @override
  void initState() {
    super.initState();
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
      progressProvider.loadSeriesProgress(widget.series.id).catchError((_) {});
    });
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
                  // Title with heart icon
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.series.title,
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
                  const SizedBox(height: 8),
                  // Episodes and year
                  Row(
                    children: [
                      Text(
                        '20 episodes', // Placeholder - can be updated when seasons data is available
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (widget.series.releaseDate != null) ...[
                        Text(
                          ' • ',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        Text(
                          '${widget.series.releaseDate.year}',
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
                              widget.series.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (widget.series.ratingsCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${widget.series.ratingsCount})',
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
                      final progress = progressProvider.getSeriesProgress(widget.series.id);
                      
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
                                            await progressProvider.loadSeriesProgress(widget.series.id);
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
                  // Series description
                  if (widget.series.description != null && widget.series.description!.isNotEmpty) ...[
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.series.description!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Genres as Wrap with chips
                  if (widget.series.genres.isNotEmpty) ...[
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
                      children: widget.series.genres.map((genre) {
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
                  if (widget.series.actors.isNotEmpty) ...[
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
                      itemCount: widget.series.actors.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final actor = widget.series.actors[index];
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
                  // Add to Watchlist Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showWatchlistSelector(context, widget.series.id);
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

