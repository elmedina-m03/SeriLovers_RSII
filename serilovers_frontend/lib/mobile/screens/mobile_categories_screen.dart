import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../models/series.dart';
import '../../providers/series_provider.dart';
import 'mobile_category_detail_screen.dart';

/// Mobile categories screen showing genres as rounded chips
class MobileCategoriesScreen extends StatefulWidget {
  const MobileCategoriesScreen({super.key});

  @override
  State<MobileCategoriesScreen> createState() => _MobileCategoriesScreenState();
}

class _MobileCategoriesScreenState extends State<MobileCategoriesScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGenres();
    });
  }

  Future<void> _loadGenres() async {
    if (_initialized) return;
    _initialized = true;
    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    await seriesProvider.fetchGenres();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: SafeArea(
        child: Consumer<SeriesProvider>(
          builder: (context, seriesProvider, child) {
            final isLoading = seriesProvider.isGenresLoading;
            final genres = seriesProvider.genres;

            return SingleChildScrollView(
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

                  if (isLoading && genres.isEmpty)
                    _buildShimmerChips()
                  else if (genres.isEmpty)
                    Text(
                      'No genres available',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    Wrap(
                      spacing: AppDim.paddingMedium,
                      runSpacing: AppDim.paddingMedium,
                      children: genres.map((genre) {
                        return _buildGenreChip(genre, context, theme);
                      }).toList(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Shimmer-like placeholders for genre chips
  Widget _buildShimmerChips() {
    return Wrap(
      spacing: AppDim.paddingMedium,
      runSpacing: AppDim.paddingMedium,
      children: List.generate(8, (index) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDim.paddingLarge,
            vertical: AppDim.paddingMedium,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppDim.radiusLarge),
          ),
          child: Container(
            width: 60,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }),
    );
  }

  /// Builds a rounded chip for a genre
  Widget _buildGenreChip(Genre genre, BuildContext context, ThemeData theme) {
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
          genre.name,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textLight,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
