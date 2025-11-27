import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/series.dart';
import '../../providers/series_provider.dart';
import '../../providers/watchlist_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';

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
        });
      }
      
      if (token != null && token.isNotEmpty && watchlistProvider.items.isEmpty) {
        watchlistProvider.fetchWatchlist(token).catchError((error) {
          // Silently fail - watchlist will be checked when button is pressed
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
        // Remove from watchlist
        await watchlistProvider.removeFromWatchlist(widget.series.id, token);
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${_series.title} removed from watchlist'),
              backgroundColor: AppColors.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Add to watchlist
        await watchlistProvider.addToWatchlist(widget.series.id);
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${_series.title} added to watchlist'),
              backgroundColor: AppColors.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
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

                  // Rating
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
                          '${_series.ratingsCount} ratings',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: AppDim.paddingLarge),

                  // Description
                  if (_series.description != null && _series.description!.isNotEmpty) ...[
                    Text(
                      'Description',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDim.paddingSmall),
                    Text(
                      _series.description!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
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
                        itemCount: _series.actors.length,
                        itemBuilder: (context, index) {
                          final actor = _series.actors[index];
                          return _buildActorCard(actor, context, theme);
                        },
                      ),
                    ),
                    const SizedBox(height: AppDim.paddingLarge),
                  ],

                  // Add/Remove from Watchlist Button
                  Consumer<WatchlistProvider>(
                    builder: (context, watchlistProvider, child) {
                      final isInWatchlist = watchlistProvider.isInWatchlist(widget.series.id);

                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _handleWatchlistToggle,
                          icon: Icon(
                            isInWatchlist ? Icons.bookmark_remove : Icons.bookmark_add,
                          ),
                          label: Text(
                            isInWatchlist ? 'Remove from Watchlist' : 'Add to Watchlist',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isInWatchlist
                                ? AppColors.dangerColor
                                : AppColors.primaryColor,
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryColor,
            AppColors.primaryColor.withOpacity(0.7),
            AppColors.accentColor,
          ],
        ),
      ),
      child: Image.network(
        'https://via.placeholder.com/800x300/5932EA/FFFFFF?text=${widget.series.title}',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppColors.primaryColor,
            child: const Center(
              child: Icon(
                Icons.movie,
                size: 80,
                color: AppColors.textLight,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds an actor card for horizontal list
  Widget _buildActorCard(Actor actor, BuildContext context, ThemeData theme) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: AppDim.paddingMedium),
      child: Column(
        children: [
          // Actor Avatar
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primaryColor.withOpacity(0.2),
            child: Icon(
              Icons.person,
              color: AppColors.primaryColor,
              size: 30,
            ),
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
}

