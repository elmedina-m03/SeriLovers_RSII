import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/series.dart';
import '../models/watchlist.dart';
import '../providers/watchlist_provider.dart';
import '../providers/series_provider.dart';
import '../providers/episode_progress_provider.dart';
import '../core/theme/app_colors.dart';
import 'watchlist_series_detail_screen.dart';

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

  @override
  Widget build(BuildContext context) {
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
                  ? Center(
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
                        ],
                      ),
                    )
                  : ListView.builder(
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
                              child: series.imageUrl != null &&
                                      series.imageUrl!.isNotEmpty
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
                                        'Episode ${progress.currentEpisodeNumber} of ${progress.totalEpisodes}',
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
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WatchlistSeriesDetailScreen(
                                    series: series,
                                    watchlistCollectionId: widget.watchlistCollectionId,
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

