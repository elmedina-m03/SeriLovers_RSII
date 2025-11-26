import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import 'mobile_category_detail_screen.dart';

/// Mobile categories screen showing genres as rounded chips
class MobileCategoriesScreen extends StatelessWidget {
  const MobileCategoriesScreen({super.key});

  /// Dummy list of genres (will be replaced with API data later)
  List<String> _getGenres() {
    return [
      'Drama',
      'Comedy',
      'Action',
      'Thriller',
      'Romance',
      'Sci-Fi',
      'Horror',
      'Fantasy',
      'Crime',
      'Mystery',
      'Adventure',
      'Documentary',
      'Animation',
      'Family',
      'Western',
      'War',
      'Musical',
      'Biography',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final genres = _getGenres();

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDim.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Text
              Padding(
                padding: const EdgeInsets.only(bottom: AppDim.paddingMedium),
                child: Text(
                  'Browse by Genre',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Genre Chips Wrapping Grid
              Wrap(
                spacing: AppDim.paddingMedium,
                runSpacing: AppDim.paddingMedium,
                children: genres.map((genre) {
                  return _buildGenreChip(genre, context, theme);
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a rounded chip for a genre
  Widget _buildGenreChip(String genre, BuildContext context, ThemeData theme) {
    return InkWell(
      onTap: () {
        // Navigate to category detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MobileCategoryDetailScreen(genre: genre),
          ),
        );
      },
      borderRadius: BorderRadius.circular(AppDim.radiusLarge),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDim.paddingLarge,
          vertical: AppDim.paddingMedium,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryColor,
          borderRadius: BorderRadius.circular(AppDim.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          genre,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textLight,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
