import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/series.dart';
import '../../models/rating.dart';
import '../../providers/rating_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';

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
        final errorMessage = e.toString();
        if (errorMessage.contains('401') || 
            errorMessage.contains('Unauthorized') ||
            errorMessage.contains('Authentication required')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your session has expired. Please log in again.'),
              backgroundColor: AppColors.dangerColor,
              duration: Duration(seconds: 3),
            ),
          );
          // Don't logout automatically - let user decide
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
              child: const Text(
                'Submit',
                style: TextStyle(
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
                      : const Text(
                          'Submit Review',
                          style: TextStyle(
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

