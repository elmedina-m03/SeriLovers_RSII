import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../models/series.dart';

/// Beautiful mobile home screen with banner, sections, and series cards
class MobileHomeScreen extends StatelessWidget {
  const MobileHomeScreen({super.key});

  /// Dummy data for "Perfect for you" section
  List<Series> _getPerfectForYouSeries() {
    return [
      Series(
        id: 1,
        title: 'Breaking Bad',
        description: 'A high school chemistry teacher turned methamphetamine manufacturer.',
        releaseDate: DateTime(2008, 1, 20),
        rating: 9.5,
        genres: ['Drama', 'Crime'],
        actors: [],
        ratingsCount: 1250,
        watchlistsCount: 890,
      ),
      Series(
        id: 2,
        title: 'Game of Thrones',
        description: 'Nine noble families fight for control over the lands of Westeros.',
        releaseDate: DateTime(2011, 4, 17),
        rating: 9.3,
        genres: ['Fantasy', 'Drama'],
        actors: [],
        ratingsCount: 2100,
        watchlistsCount: 1500,
      ),
      Series(
        id: 3,
        title: 'The Crown',
        description: 'Follows the political rivalries and romance of Queen Elizabeth II.',
        releaseDate: DateTime(2016, 11, 4),
        rating: 8.7,
        genres: ['Drama', 'History'],
        actors: [],
        ratingsCount: 980,
        watchlistsCount: 720,
      ),
      Series(
        id: 4,
        title: 'Stranger Things',
        description: 'When a young boy vanishes, a small town uncovers a mystery.',
        releaseDate: DateTime(2016, 7, 15),
        rating: 8.8,
        genres: ['Sci-Fi', 'Horror'],
        actors: [],
        ratingsCount: 1850,
        watchlistsCount: 1320,
      ),
      Series(
        id: 5,
        title: 'The Office',
        description: 'A mockumentary on a group of typical office workers.',
        releaseDate: DateTime(2005, 3, 24),
        rating: 8.9,
        genres: ['Comedy'],
        actors: [],
        ratingsCount: 1650,
        watchlistsCount: 1100,
      ),
    ];
  }

  /// Dummy data for "For this summer" section
  List<Map<String, dynamic>> _getSummerSeries() {
    return [
      {
        'title': 'Outer Banks',
        'rating': 7.6,
      },
      {
        'title': 'The Summer I Turned Pretty',
        'rating': 7.8,
      },
      {
        'title': 'Virgin River',
        'rating': 7.4,
      },
      {
        'title': 'Emily in Paris',
        'rating': 7.1,
      },
      {
        'title': 'The White Lotus',
        'rating': 8.2,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Placeholder
              Container(
                height: 180,
                margin: const EdgeInsets.all(AppDim.paddingMedium),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.movie,
                    size: 64,
                    color: AppColors.textLight.withOpacity(0.8),
                  ),
                ),
              ),

              // "Perfect for you" Section
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDim.paddingMedium,
                  AppDim.paddingSmall,
                  AppDim.paddingMedium,
                  AppDim.paddingSmall,
                ),
                child: Text(
                  'Perfect for you',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),

              // Horizontal ListView of series cards
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
                  itemCount: _getPerfectForYouSeries().length,
                  itemBuilder: (context, index) {
                    final series = _getPerfectForYouSeries()[index];
                    return _buildSeriesCard(series, context, theme);
                  },
                ),
              ),

              const SizedBox(height: AppDim.paddingLarge),

              // "For this summer" Section
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDim.paddingMedium,
                  AppDim.paddingSmall,
                  AppDim.paddingMedium,
                  AppDim.paddingSmall,
                ),
                child: Text(
                  'For this summer',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),

              // Another horizontal list
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
                  itemCount: _getSummerSeries().length,
                  itemBuilder: (context, index) {
                    final item = _getSummerSeries()[index];
                    return _buildSummerCard(item, context, theme);
                  },
                ),
              ),

              const SizedBox(height: AppDim.paddingLarge),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a series card for "Perfect for you" section
  Widget _buildSeriesCard(Series series, BuildContext context, ThemeData theme) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: AppDim.paddingMedium),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/series_detail',
              arguments: series,
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Series Image Placeholder
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.2),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.movie,
                    size: 40,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
              // Series Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        series.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: AppColors.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            series.rating.toStringAsFixed(1),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a card for "For this summer" section
  Widget _buildSummerCard(Map<String, dynamic> item, BuildContext context, ThemeData theme) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: AppDim.paddingMedium),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        child: InkWell(
          onTap: () {
            // TODO: Navigate to series detail
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Series Image Placeholder
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryColor,
                      AppColors.accentColor,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.movie,
                    size: 40,
                    color: AppColors.textLight,
                  ),
                ),
              ),
              // Series Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: AppColors.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (item['rating'] as double).toStringAsFixed(1),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
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
