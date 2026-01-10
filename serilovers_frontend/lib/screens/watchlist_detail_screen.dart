import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/series.dart';
import '../models/watchlist.dart';
import '../providers/watchlist_provider.dart';
import '../providers/episode_progress_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/series_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/image_with_placeholder.dart';
import 'watchlist_series_detail_screen.dart';
import '../mobile/screens/mobile_series_detail_screen.dart';

class WatchlistDetailScreen extends StatefulWidget {
  final int watchlistCollectionId;

  const WatchlistDetailScreen({
    super.key,
    required this.watchlistCollectionId,
  });

  @override
  State<WatchlistDetailScreen> createState() => _WatchlistDetailScreenState();
}

class _WatchlistDetailScreenState extends State<WatchlistDetailScreen> {
  Watchlist? _watchlist;
  List<Series> _series = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);

      // Find the watchlist in the provider's list
      final lists = watchlistProvider.lists;
      _watchlist = lists.firstWhere(
        (list) => list.id == widget.watchlistCollectionId,
        orElse: () => lists.isNotEmpty ? lists.first : Watchlist(
          id: widget.watchlistCollectionId,
          name: 'Watchlist',
          coverUrl: '',
          totalSeries: 0,
          createdAt: DateTime.now(),
        ),
      );

      // Load watchlist collection with series from API
      final collectionData = await watchlistProvider.getWatchlistCollection(
        widget.watchlistCollectionId,
      );

      // Extract series from watchlists
      final watchlists = collectionData['watchlists'] as List?;
      if (watchlists != null && watchlists.isNotEmpty) {
        _series = watchlists
            .map((w) {
              if (w is Map<String, dynamic>) {
                return w['series'] as Map<String, dynamic>?;
              }
              return null;
            })
            .where((s) => s != null)
            .map((s) => Series.fromJson(s!))
            .toList();
        
        // Load episode progress for all series
        final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
        for (final series in _series) {
          try {
            await progressProvider.loadSeriesProgress(series.id);
          } catch (_) {
            // Silently fail - progress just won't show for that series
          }
        }
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Builds a visual header for the list on mobile/web, using the list cover image if available.
  Widget _buildMobileHeader() {
    final watchlist = _watchlist;
    final hasCover = watchlist != null && watchlist.coverUrl.isNotEmpty;

    if (!hasCover) {
      // If no cover image was set for this list, don't fabricate one here;
      // the placeholder section below will represent the list visually.
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 200,
          child: ImageWithPlaceholder(
            // Use the watchlist coverUrl as the main visual representation
            imageUrl: watchlist.coverUrl,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            borderRadius: 0,
            // Keep a very subtle placeholder only if imageUrl is actually empty,
            // which won't be the case here because hasCover was already checked.
            placeholderIcon: Icons.image,
            placeholderIconSize: 40,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _showRemoveDialog(BuildContext context, Series series) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Series'),
        content: Text('Are you sure you want to remove "${series.title}" from this list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _removeSeries(series.id);
    }
  }

  Future<void> _showAddSeriesDialog(BuildContext context) async {
    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
    
    // Load all series if not already loaded
    if (seriesProvider.items.isEmpty) {
      await seriesProvider.fetchSeries(page: 1, pageSize: 100);
    }
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Series to List'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: seriesProvider.items.length,
            itemBuilder: (context, index) {
              final series = seriesProvider.items[index];
              // Check if series is already in the list
              final isInList = _series.any((s) => s.id == series.id);
              
              return ListTile(
                leading: series.imageUrl != null && series.imageUrl!.isNotEmpty
                    ? Image.network(
                        series.imageUrl!,
                        width: 50,
                        height: 75,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.movie);
                        },
                      )
                    : const Icon(Icons.movie),
                title: Text(series.title),
                subtitle: Text('${series.releaseDate.year}'),
                trailing: isInList
                    ? const Icon(Icons.check, color: Colors.green)
                    : IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () async {
                          try {
                            await watchlistProvider.addSeries(
                              widget.watchlistCollectionId,
                              series.id,
                            );
                            await _loadWatchlist();
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${series.title} added to list'),
                                  backgroundColor: AppColors.successColor,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error adding series: $e'),
                                  backgroundColor: AppColors.dangerColor,
                                ),
                              );
                            }
                          }
                        },
                      ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeSeries(int seriesId) async {
    final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to manage your lists'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
      return;
    }

    // Guard: Prevent delete if already being deleted
    if (watchlistProvider.isDeletingSeries(widget.watchlistCollectionId, seriesId)) {
      return; // Already deleting, ignore duplicate request
    }

    // Optimistically remove from local state immediately
    setState(() {
      _series.removeWhere((s) => s.id == seriesId);
    });

    try {
      await watchlistProvider.removeSeriesFromList(
        widget.watchlistCollectionId,
        seriesId,
      );

      // Reload the watchlist to refresh the UI and get accurate counts
      await _loadWatchlist();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Series removed from list'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      // Rollback: Reload to restore the series if delete failed
      await _loadWatchlist();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing series: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobileWidth = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _watchlist?.name ?? 'Watchlist',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Track your series easily',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ],
        ),
        titleSpacing: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    'Error: $_error',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : _series.isEmpty
                  ? (isMobileWidth
                      // Mobile/web: show list cover header above the empty-state message
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildMobileHeader(),
                                const SizedBox(height: 24),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.movie_outlined,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No series in this list yet',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton.icon(
                                        onPressed: () => _showAddSeriesDialog(context),
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add Series'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : // Desktop: keep existing centered empty state
                      Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.movie_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No series in this list yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _showAddSeriesDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Series'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                        ))
                  : isMobileWidth
                      // Mobile/web: show list cover header and then the series list
                      ? CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: _buildMobileHeader(),
                              ),
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final series = _series[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    child: Card(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(12),
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: series.imageUrl != null && series.imageUrl!.isNotEmpty
                                              ? Image.network(
                                                  series.imageUrl!,
                                                  width: 60,
                                                  height: 90,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      width: 60,
                                                      height: 90,
                                                      color: Colors.grey[300],
                                                      child: const Icon(Icons.movie),
                                                    );
                                                  },
                                                )
                                              : Container(
                                                  width: 60,
                                                  height: 90,
                                                  color: Colors.grey[300],
                                                  child: const Icon(Icons.movie),
                                                ),
                                        ),
                                        title: Text(
                                          series.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Consumer<EpisodeProgressProvider>(
                                          builder: (context, progressProvider, child) {
                                            final progress = progressProvider.getSeriesProgress(series.id);

                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4),
                                                Text('${series.releaseDate.year}'),
                                                const SizedBox(height: 4),
                                                // Episode progress - Always show progress bar
                                                if (progress != null && progress.totalEpisodes > 0) ...[
                                                  Text(
                                                    '${progress.watchedEpisodes}/${progress.totalEpisodes}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: LinearProgressIndicator(
                                                      value: progress.progressPercentage / 100,
                                                      minHeight: 6,
                                                      backgroundColor: Colors.grey[300],
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        AppColors.primaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                ] else ...[
                                                  // Show default progress bar even if no progress data
                                                  Text(
                                                    'Not started',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: LinearProgressIndicator(
                                                      value: 0.0,
                                                      minHeight: 6,
                                                      backgroundColor: Colors.grey[300],
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        AppColors.primaryColor.withOpacity(0.3),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            );
                                          },
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Consumer<WatchlistProvider>(
                                              builder: (context, watchlistProvider, child) {
                                                final isDeleting = watchlistProvider.isDeletingSeries(
                                                  widget.watchlistCollectionId,
                                                  series.id,
                                                );
                                                return IconButton(
                                                  icon: isDeleting
                                                      ? const SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                                          ),
                                                        )
                                                      : const Icon(Icons.delete_outline, color: Colors.red),
                                                  onPressed: isDeleting
                                                      ? null
                                                      : () => _showRemoveDialog(context, series),
                                                  tooltip: isDeleting ? 'Removing...' : 'Remove from list',
                                                );
                                              },
                                            ),
                                            const Icon(Icons.chevron_right),
                                          ],
                                        ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => MobileSeriesDetailScreen(
                                                series: series,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                                childCount: _series.length,
                              ),
                            ),
                          ],
                        )
                      : // Desktop: keep original list-only behavior
                      ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _series.length,
                      itemBuilder: (context, index) {
                        final series = _series[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                                  child: series.imageUrl != null && series.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      series.imageUrl!,
                                      width: 60,
                                      height: 90,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 60,
                                          height: 90,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.movie),
                                        );
                                      },
                                    )
                                  : Container(
                                      width: 60,
                                      height: 90,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.movie),
                                    ),
                            ),
                            title: Text(
                              series.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Consumer<EpisodeProgressProvider>(
                              builder: (context, progressProvider, child) {
                                final progress = progressProvider.getSeriesProgress(series.id);
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('${series.releaseDate.year}'),
                                    const SizedBox(height: 4),
                                    // Episode progress - Always show progress bar
                                    if (progress != null && progress.totalEpisodes > 0) ...[
                                      Text(
                                        '${progress.watchedEpisodes}/${progress.totalEpisodes}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progress.progressPercentage / 100,
                                          minHeight: 6,
                                          backgroundColor: Colors.grey[300],
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      // Show default progress bar even if no progress data
                                      Text(
                                        'Not started',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: 0.0,
                                          minHeight: 6,
                                          backgroundColor: Colors.grey[300],
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.primaryColor.withOpacity(0.3),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Consumer<WatchlistProvider>(
                                  builder: (context, watchlistProvider, child) {
                                    final isDeleting = watchlistProvider.isDeletingSeries(
                                      widget.watchlistCollectionId,
                                      series.id,
                                    );
                                    return IconButton(
                                      icon: isDeleting
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                              ),
                                            )
                                          : const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: isDeleting
                                          ? null
                                          : () => _showRemoveDialog(context, series),
                                      tooltip: isDeleting ? 'Removing...' : 'Remove from list',
                                    );
                                  },
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MobileSeriesDetailScreen(
                                    series: series,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}

