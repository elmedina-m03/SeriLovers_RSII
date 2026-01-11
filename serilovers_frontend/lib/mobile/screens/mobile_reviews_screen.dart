import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/series.dart';
import '../../models/rating.dart';
import '../../providers/rating_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/episode_progress_provider.dart';
import '../../providers/series_provider.dart';
import '../../services/episode_progress_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../widgets/mobile_page_route.dart';
import 'mobile_add_review_screen.dart';

/// Full reviews screen showing all reviews for a series
class MobileReviewsScreen extends StatefulWidget {
  final Series series;

  const MobileReviewsScreen({
    super.key,
    required this.series,
  });

  @override
  State<MobileReviewsScreen> createState() => _MobileReviewsScreenState();
}

class _MobileReviewsScreenState extends State<MobileReviewsScreen> {
  bool _isLoading = true;
  bool _canAddReview = false;
  Rating? _myRating; // User's existing rating for this series

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final ratingProvider = Provider.of<RatingProvider>(context, listen: false);
    final progressProvider = Provider.of<EpisodeProgressProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    try {
      // Load reviews (public - doesn't require authentication)
      await ratingProvider.loadSeriesRatings(widget.series.id);

      // Check if user can add review (all episodes in all seasons must be watched)
      // Only check if user is authenticated
      if (authProvider.isAuthenticated && authProvider.token != null && authProvider.token!.isNotEmpty) {
        try {
          // Load user's existing rating for this series
          await ratingProvider.loadMyRating(widget.series.id);
          _myRating = ratingProvider.getMyRating(widget.series.id);

          // Get all watched episodes for this series
          final progressService = EpisodeProgressService();
          final userProgress = await progressService.getUserProgress(token: authProvider.token);
          final watchedEpisodeIds = userProgress
              .where((p) => p.seriesId == widget.series.id)
              .map((p) => p.episodeId)
              .toSet();
          
          // Get total episodes from series (all seasons)
          final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
          final seriesDetail = await seriesProvider.fetchSeriesDetail(widget.series.id);
          
          if (seriesDetail != null && seriesDetail.seasons.isNotEmpty) {
            // Count all episodes across all seasons
            final totalEpisodes = seriesDetail.seasons
                .expand((season) => season.episodes)
                .length;
            
            // Count watched episodes
            final watchedCount = seriesDetail.seasons
                .expand((season) => season.episodes)
                .where((episode) => watchedEpisodeIds.contains(episode.id))
                .length;
            
            // Can add review only if all episodes are watched AND user doesn't already have a rating
            _canAddReview = totalEpisodes > 0 && watchedCount >= totalEpisodes && _myRating == null;
          } else {
            // Fallback to progress percentage if series detail not available
            final progress = await progressProvider.loadSeriesProgress(widget.series.id);
            _canAddReview = progress != null && progress.progressPercentage >= 100 && _myRating == null;
          }
        } catch (_) {
          _canAddReview = false;
        }
      } else {
        _canAddReview = false;
      }
    } catch (e) {
      // Handle error silently - reviews can still be viewed even if there's an error
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Reviews',
          style: TextStyle(color: AppColors.textLight),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<RatingProvider>(
              builder: (context, ratingProvider, child) {
                final reviews = ratingProvider.getSeriesRatings(widget.series.id);

                return Column(
                  children: [
                    // Action Buttons (Add/Edit/Delete Review)
                    if (_canAddReview || _myRating != null)
                      Padding(
                        padding: const EdgeInsets.all(AppDim.paddingMedium),
                        child: Row(
                          children: [
                            // Add Review Button (only if user doesn't have a rating)
                            if (_canAddReview)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MobilePageRoute(
                                        builder: (context) => MobileAddReviewScreen(
                                          series: widget.series,
                                        ),
                                      ),
                                    );
                                    if (result == true && mounted) {
                                      // Add small delay to ensure backend has processed the new rating
                                      await Future.delayed(const Duration(milliseconds: 500));
                                      
                                      if (!mounted) return;
                                      
                                      // Refresh reviews list to ensure new review is displayed
                                      final ratingProvider = Provider.of<RatingProvider>(context, listen: false);
                                      await ratingProvider.loadSeriesRatings(widget.series.id);
                                      
                                      // Reload user's rating to update _myRating and _canAddReview
                                      try {
                                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                        if (authProvider.isAuthenticated && authProvider.token != null && authProvider.token!.isNotEmpty) {
                                      if (!mounted) return;
                                          await ratingProvider.loadMyRating(widget.series.id);
                                      if (mounted) {
                                            setState(() {
                                              _myRating = ratingProvider.getMyRating(widget.series.id);
                                              _canAddReview = _myRating == null;
                                            });
                                          }
                                        }
                                      } catch (_) {
                                        // Silently fail
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.add_comment),
                                  label: const Text('Add Review'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppDim.paddingMedium,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                                    ),
                                  ),
                                ),
                              ),
                            // Edit/Delete Review Buttons (if user already has a rating)
                            if (_myRating != null) ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MobilePageRoute(
                                        builder: (context) => MobileAddReviewScreen(
                                          series: widget.series,
                                        ),
                                      ),
                                    );
                                    if (result == true && mounted) {
                                      // Add small delay to ensure backend has processed the updated rating
                                      await Future.delayed(const Duration(milliseconds: 500));
                                      
                                      if (!mounted) return;
                                      
                                      // Refresh reviews list to ensure updated review is displayed
                                      final ratingProvider = Provider.of<RatingProvider>(context, listen: false);
                                      await ratingProvider.loadSeriesRatings(widget.series.id);
                                      
                                      // Reload user's rating to update _myRating and _canAddReview
                                      try {
                                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                        if (authProvider.isAuthenticated && authProvider.token != null && authProvider.token!.isNotEmpty) {
                                      if (!mounted) return;
                                          await ratingProvider.loadMyRating(widget.series.id);
                                      if (mounted) {
                                            setState(() {
                                              _myRating = ratingProvider.getMyRating(widget.series.id);
                                              _canAddReview = _myRating == null;
                                            });
                                          }
                                        }
                                      } catch (_) {
                                        // Silently fail
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit Review'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppDim.paddingMedium,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppDim.paddingSmall),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  // Show confirmation dialog
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Review'),
                                      content: const Text('Are you sure you want to delete your review? This action cannot be undone.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.dangerColor,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                    if (confirm == true && mounted && _myRating != null) {
                                      // Get provider references BEFORE async operations
                                      final ratingProvider = Provider.of<RatingProvider>(context, listen: false);
                                      
                                      try {
                                        await ratingProvider.deleteRating(_myRating!.id, widget.series.id);
                                        
                                        // Refresh reviews list
                                        if (!mounted) return;
                                        await ratingProvider.loadSeriesRatings(widget.series.id);
                                        
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Review deleted successfully'),
                                              backgroundColor: AppColors.successColor,
                                            ),
                                          );
                                          // Update UI state
                                          setState(() {
                                            _myRating = null;
                                            _canAddReview = true;
                                          });
                                        }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to delete review: $e'),
                                            backgroundColor: AppColors.dangerColor,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.dangerColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppDim.paddingMedium,
                                    horizontal: AppDim.paddingMedium,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    // Reviews List
                    Expanded(
                      child: reviews.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.comment_outlined,
                                    size: 64,
                                    color: AppColors.textSecondary.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: AppDim.paddingMedium),
                                  Text(
                                    'No reviews yet',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (!_canAddReview)
                                    Padding(
                                      padding: const EdgeInsets.only(top: AppDim.paddingSmall),
                                      child: Text(
                                        'Finish watching to add a review',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(AppDim.paddingMedium),
                              itemCount: reviews.length,
                              itemBuilder: (context, index) {
                                final review = reviews[index];
                                return _buildReviewCard(review, theme);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildReviewCard(Rating review, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDim.paddingMedium),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppDim.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User name and date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  review.userName ?? 'Anonymous',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _formatDate(review.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDim.paddingSmall),
            // Star rating
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < review.starRating
                      ? Icons.star
                      : Icons.star_border,
                  size: 20,
                  color: Colors.amber,
                );
              }),
            ),
            // Comment
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: AppDim.paddingSmall),
              Text(
                review.comment!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

