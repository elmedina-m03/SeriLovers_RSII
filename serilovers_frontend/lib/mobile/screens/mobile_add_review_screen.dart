import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../models/series.dart';
import '../../models/rating.dart';
import '../../providers/rating_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/episode_progress_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../providers/mobile_challenges_provider.dart';

/// Screen for adding/editing a review for a series
class MobileAddReviewScreen extends StatefulWidget {
  final Series series;

  const MobileAddReviewScreen({
    super.key,
    required this.series,
  });

  @override
  State<MobileAddReviewScreen> createState() => _MobileAddReviewScreenState();
}

class _MobileAddReviewScreenState extends State<MobileAddReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  int _selectedRating = 5; // Default to 5 stars
  bool _isLoading = false;
  Rating? _existingRating;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingReview();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingReview() async {
    final ratingProvider = Provider.of<RatingProvider>(context, listen: false);
    
    try {
      await ratingProvider.loadMyRating(widget.series.id);
      final existing = ratingProvider.getMyRating(widget.series.id);
      
      if (existing != null && mounted) {
        setState(() {
          _existingRating = existing;
          _selectedRating = existing.starRating;
          _commentController.text = existing.comment ?? '';
        });
      }
    } catch (_) {
      // Silently fail
    }
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final ratingProvider = Provider.of<RatingProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to add a review'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Verify authentication before submitting
      if (!authProvider.isAuthenticated || authProvider.token == null || authProvider.token!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your session has expired. Please log in again.'),
              backgroundColor: AppColors.dangerColor,
            ),
          );
        }
        return;
      }

      // Prevent admins from rating
      try {
        final decodedToken = JwtDecoder.decode(authProvider.token!);
        final userRole = decodedToken['role'] as String?;
        if (userRole == 'Admin') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Admins cannot rate series. Only regular users can submit ratings.'),
                backgroundColor: AppColors.dangerColor,
                duration: Duration(seconds: 4),
              ),
            );
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
      } catch (e) {
        print('Error decoding token: $e');
      }

      // Check if series has seasons
      final totalSeasons = widget.series.totalSeasons;
      if (totalSeasons == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This series has no seasons yet. You cannot rate it.'),
              backgroundColor: AppColors.dangerColor,
              duration: Duration(seconds: 4),
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Check if series has episodes
      final totalEpisodes = widget.series.totalEpisodes;
      if (totalEpisodes == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This series has no episodes yet. You cannot rate it.'),
              backgroundColor: AppColors.dangerColor,
              duration: Duration(seconds: 4),
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Check if user has completed all episodes
      final progressService = EpisodeProgressService();
      final userProgress = await progressService.getUserProgress(token: authProvider.token!);
      final completedEpisodes = userProgress
          .where((p) => p.seriesId == widget.series.id && p.isCompleted)
          .length;
      
      if (completedEpisodes < totalEpisodes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You can rate this series after watching all episodes. You have watched $completedEpisodes of $totalEpisodes episodes.'),
              backgroundColor: AppColors.dangerColor,
              duration: const Duration(seconds: 5),
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Convert star rating (1-5) to score (1-10)
      // 1 star = 2, 2 stars = 4, 3 stars = 6, 4 stars = 8, 5 stars = 10
      final score = _selectedRating * 2;

      await ratingProvider.createOrUpdateRating(
        seriesId: widget.series.id,
        score: score,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      // Review is already added to cache in createOrUpdateRating
      // Refresh from API to ensure we have the latest data (with a small delay to ensure DB is updated)
      await Future.delayed(const Duration(milliseconds: 300));
      await ratingProvider.loadSeriesRatings(widget.series.id);

      // Refresh challenge progress since rating a series counts towards challenges
      try {
        final challengesProvider = Provider.of<MobileChallengesProvider>(context, listen: false);
        await challengesProvider.fetchMyProgress();
      } catch (e) {
        // Don't fail if challenge refresh fails
        print('Error refreshing challenges: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: AppColors.successColor,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        // Check if it's an authentication error
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('401') || 
            errorMessage.contains('unauthorized') ||
            errorMessage.contains('authentication required')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your session has expired. Please log in again.'),
              backgroundColor: AppColors.dangerColor,
              duration: Duration(seconds: 3),
            ),
          );
          // Don't logout automatically - let user decide
        } else if (errorMessage.contains('finish') && errorMessage.contains('series')) {
          // Friendly notification for needing to finish the series
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Watch all episodes to leave a review',
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting review: ${e.toString().replaceAll('ApiException: ', '')}'),
              backgroundColor: AppColors.dangerColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
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
          _existingRating != null ? 'Edit Review' : 'Add Review',
          style: TextStyle(color: AppColors.textLight),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        actions: [
          // Delete button (only if editing existing review)
          if (_existingRating != null && !_isLoading)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Delete Review',
              onPressed: () async {
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

                if (confirm == true && mounted && _existingRating != null) {
                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    final ratingProvider = Provider.of<RatingProvider>(context, listen: false);
                    await ratingProvider.deleteRating(_existingRating!.id, widget.series.id);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Review deleted successfully'),
                          backgroundColor: AppColors.successColor,
                        ),
                      );
                      Navigator.of(context).pop(true); // Return true to indicate success
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete review: ${e.toString().replaceAll('ApiException: ', '')}'),
                          backgroundColor: AppColors.dangerColor,
                        ),
                      );
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                }
              },
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _submitReview,
              child: Text(
                _existingRating != null ? 'Update' : 'Submit',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDim.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Series Title
              Text(
                widget.series.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppDim.paddingLarge),

              // Rating Section
              Text(
                'Your Rating',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppDim.paddingMedium),
              // Star Rating Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  final isSelected = rating <= _selectedRating;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRating = rating;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        isSelected ? Icons.star : Icons.star_border,
                        size: 48,
                        color: isSelected ? Colors.amber : AppColors.textSecondary,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppDim.paddingLarge),

              // Comment Section
              Text(
                'Your Review (Optional)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppDim.paddingMedium),
              TextFormField(
                controller: _commentController,
                maxLines: 8,
                maxLength: 2000,
                decoration: InputDecoration(
                  hintText: 'Share your thoughts about this series...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.primaryColor.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                    borderSide: BorderSide(color: AppColors.primaryColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                    borderSide: BorderSide(color: AppColors.primaryColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDim.radiusMedium),
                    borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                  ),
                ),
                style: TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppDim.paddingLarge),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReview,
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
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _existingRating != null ? 'Update Review' : 'Submit Review',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

