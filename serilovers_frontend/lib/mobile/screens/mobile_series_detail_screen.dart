import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../models/series.dart';
import '../../models/watchlist.dart';
import '../../providers/series_provider.dart';
import '../../providers/watchlist_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/episode_review_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../core/widgets/image_with_placeholder.dart';

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

                  // Episode count and release year with heart icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_series.releaseDate.year}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      // Heart icon positioned like in prototype
                      Consumer<WatchlistProvider>(
                        builder: (context, watchlistProvider, child) {
                          return FutureBuilder<bool>(
                            future: watchlistProvider.isInFavorites(_series.id),
                            builder: (context, snapshot) {
                              final isFavorite = snapshot.data ?? false;
                              return IconButton(
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
                                      // Refresh the screen
                                      setState(() {});
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

                  // Description with Read more
                  if (_series.description != null && _series.description!.isNotEmpty) ...[
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
                        itemCount: _series.actors.length,
                        itemBuilder: (context, index) {
                          final actor = _series.actors[index];
                          return _buildActorCard(actor, context, theme);
                        },
                      ),
                    ),
                    const SizedBox(height: AppDim.paddingLarge),
                  ],

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
                      onPressed: () {
                        // Navigate to full reviews screen
                        // For now, show a placeholder
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reviews feature coming soon'),
                          ),
                        );
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
    // Placeholder reviews - in real implementation, fetch from API
    final placeholderReviews = [
      {'name': 'Adina K.', 'rating': 5, 'comment': 'Loved every episode!'},
      {'name': 'Emma K.', 'rating': 5, 'comment': 'Amazing story!'},
    ];

    return Column(
      children: placeholderReviews.map((review) {
        return Card(
          margin: const EdgeInsets.only(bottom: AppDim.paddingSmall),
          child: ListTile(
            title: Text(
              review['name'] as String,
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
                      index < (review['rating'] as int)
                          ? Icons.star
                          : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  review['comment'] as String,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDescription(String description, ThemeData theme) {
    const maxLength = 150;
    final isLong = description.length > maxLength;
    final displayText = _isDescriptionExpanded || !isLong
        ? description
        : '${description.substring(0, maxLength)}...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayText,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        if (isLong)
          TextButton(
            onPressed: () {
              setState(() {
                _isDescriptionExpanded = !_isDescriptionExpanded;
              });
            },
            child: Text(
              _isDescriptionExpanded ? 'Read less' : 'Read more',
              style: TextStyle(color: AppColors.primaryColor),
            ),
          ),
      ],
    );
  }

  Future<void> _handleRatingTap(int rating) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
      // For now, show a message that rating is saved
      // In a full implementation, you would need to get the first episode ID
      // and submit a review for that episode, or use a series-level rating endpoint
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate API call
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You rated this series ${rating} star${rating > 1 ? 's' : ''}'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userRating = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRatingLoading = false;
        });
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

    // Load user's lists if not already loaded
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
                                      }
                                    } catch (_) {
                                      // Silently fail - refresh is optional
                                    }

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

