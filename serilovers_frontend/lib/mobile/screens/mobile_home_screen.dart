import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../models/series.dart';
import '../../providers/series_provider.dart';
import '../../providers/watchlist_provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/series_detail_screen.dart';
import '../models/series_filter.dart';
import '../widgets/fade_slide_transition.dart';
import '../widgets/mobile_page_route.dart';
import 'mobile_filter_screen.dart';
import 'mobile_series_detail_screen.dart';
import 'mobile_search_screen.dart';
import '../../core/widgets/image_with_placeholder.dart';
import '../../core/widgets/horizontal_paginated_list.dart';

/// Beautiful mobile home screen with banner, sections, and series cards
class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  bool _initialized = false;
  SeriesFilter? _activeFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSeries();
    });
  }

  Future<void> _loadSeries() async {
    if (_initialized) return;
    _initialized = true;

    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    try {
      // Load initial batch for pagination
      await seriesProvider.fetchSeries(page: 1, pageSize: 20);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading series: $e'),
          backgroundColor: AppColors.dangerColor,
        ),
      );
    }
  }

  List<Series> _applyFilter(List<Series> items) {
    if (_activeFilter == null || _activeFilter!.isEmpty) {
      return items;
    }

    return items.where((series) {
      final matchesGenre = _activeFilter!.genre == null ||
          series.genres.any((genre) => genre.toLowerCase() == _activeFilter!.genre!.name.toLowerCase());
      final releaseYear = series.releaseDate.year;
      final matchesStart = _activeFilter!.startYear == null || releaseYear >= _activeFilter!.startYear!;
      final matchesEnd = _activeFilter!.endYear == null || releaseYear <= _activeFilter!.endYear!;
      return matchesGenre && matchesStart && matchesEnd;
    }).toList();
  }

  Future<void> _openFilter() async {
    final result = await Navigator.push<SeriesFilter?>(
      context,
      MobilePageRoute(
        builder: (context) => MobileFilterScreen(initialFilter: _activeFilter),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _activeFilter = result.isEmpty ? null : result;
    });
  }

  List<Series> _getPerfectForYou(List<Series> all) {
    return all.where((s) => s.rating > 7).toList();
  }

  List<Series> _getSummerSeries(List<Series> all) {
    return all
        .where((s) => s.releaseDate.year >= 2023 && s.releaseDate.year <= 2025)
        .toList();
  }

  Series? _getTopRated(List<Series> all) {
    final filtered = all.where((s) => s.rating > 8).toList();
    if (filtered.isEmpty) return null;
    filtered.sort((a, b) => b.rating.compareTo(a.rating));
    return filtered.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('SeriLovers'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MobileSearchScreen(),
                ),
              );
            },
            tooltip: 'Search',
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<SeriesProvider>(
          builder: (context, seriesProvider, child) {
            final isLoading = seriesProvider.isLoading && seriesProvider.items.isEmpty;
            final filteredItems = _applyFilter(seriesProvider.items);

            final perfectForYou = _getPerfectForYou(filteredItems);
            final summerSeries = _getSummerSeries(filteredItems);
            final topRated = _getTopRated(filteredItems);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner - show shimmer or real top-rated series
                  Padding(
                    padding: const EdgeInsets.all(AppDim.paddingMedium),
                    child: isLoading
                        ? _buildBannerShimmer()
                        : _buildBanner(
                            topRated ?? (filteredItems.isNotEmpty ? filteredItems.first : null),
                            theme,
                          ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _openFilter,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: AppColors.textLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                            ),
                          ),
                          icon: const Icon(Icons.filter_list),
                          label: const Text('Filters'),
                        ),
                        const SizedBox(width: AppDim.paddingSmall),
                        if (_activeFilter != null)
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (_activeFilter!.genre != null)
                                  _buildFilterChip('Genre: ${_activeFilter!.genre!.name}'),
                                if (_activeFilter!.startYear != null)
                                  _buildFilterChip('From ${_activeFilter!.startYear}'),
                                if (_activeFilter!.endYear != null)
                                  _buildFilterChip('To ${_activeFilter!.endYear}'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDim.paddingMedium),

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

                  isLoading && perfectForYou.isEmpty
                      ? SizedBox(height: 200, child: _buildSeriesShimmerList())
                      : perfectForYou.isEmpty
                          ? SizedBox(height: 200, child: _buildEmptySectionMessage('No recommendations yet'))
                          : HorizontalPaginatedList<Series>(
                              height: 200,
                              items: perfectForYou,
                              itemBuilder: (context, series, index) {
                                return FadeSlideTransition(
                                  delay: index * 50,
                                  direction: SlideDirection.right,
                                  child: _buildSeriesCard(series, context, theme),
                                );
                              },
                              onLoadMore: () async {
                                final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
                                if (seriesProvider.hasMore) {
                                  await seriesProvider.loadMoreSeries();
                                  // Re-filter after loading more
                                  if (mounted) {
                                    setState(() {});
                                  }
                                }
                              },
                              hasMore: seriesProvider.hasMore && perfectForYou.length < seriesProvider.items.length,
                              isLoadingMore: seriesProvider.isLoading,
                              padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
                              spacing: AppDim.paddingMedium,
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

                  isLoading && summerSeries.isEmpty
                      ? SizedBox(height: 200, child: _buildSeriesShimmerList())
                      : summerSeries.isEmpty
                          ? SizedBox(height: 200, child: _buildEmptySectionMessage('No summer picks yet'))
                          : HorizontalPaginatedList<Series>(
                              height: 200,
                              items: summerSeries,
                              itemBuilder: (context, series, index) {
                                return FadeSlideTransition(
                                  delay: index * 50,
                                  direction: SlideDirection.right,
                                  child: _buildSeriesCard(series, context, theme),
                                );
                              },
                              onLoadMore: () async {
                                final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
                                if (seriesProvider.hasMore) {
                                  await seriesProvider.loadMoreSeries();
                                  if (mounted) {
                                    setState(() {});
                                  }
                                }
                              },
                              hasMore: seriesProvider.hasMore && summerSeries.length < seriesProvider.items.length,
                              isLoadingMore: seriesProvider.isLoading,
                              padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
                              spacing: AppDim.paddingMedium,
                            ),

                  const SizedBox(height: AppDim.paddingLarge),

                  // "All Series" Section - Show more series
                  if (filteredItems.length > (perfectForYou.length + summerSeries.length)) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDim.paddingMedium,
                        AppDim.paddingSmall,
                        AppDim.paddingMedium,
                        AppDim.paddingSmall,
                      ),
                      child: Text(
                        'All Series',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    HorizontalPaginatedList<Series>(
                      height: 200,
                      items: filteredItems
                          .where((series) => !perfectForYou.contains(series) && !summerSeries.contains(series))
                          .take(50)
                          .toList(),
                      itemBuilder: (context, series, index) {
                        return FadeSlideTransition(
                          delay: index * 30,
                          direction: SlideDirection.right,
                          child: _buildSeriesCard(series, context, theme),
                        );
                      },
                      onLoadMore: () async {
                        final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
                        if (seriesProvider.hasMore) {
                          await seriesProvider.loadMoreSeries();
                          if (mounted) {
                            setState(() {});
                          }
                        }
                      },
                      hasMore: seriesProvider.hasMore,
                      isLoadingMore: seriesProvider.isLoading,
                      padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
                      spacing: AppDim.paddingMedium,
                    ),
                    const SizedBox(height: AppDim.paddingLarge),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Banner with big image and overlay - Clickable to go to series detail
  Widget _buildBanner(Series? series, ThemeData theme) {
    if (series == null) {
      return _buildBannerShimmer();
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MobilePageRoute(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              if (screenWidth < 900) {
                return MobileSeriesDetailScreen(series: series);
              } else {
                return SeriesDetailScreen(series: series);
              }
            },
          ),
        );
      },
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDim.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDim.radiusLarge),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Series Image
              ImageWithPlaceholder(
                imageUrl: series.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholderIcon: Icons.movie,
                placeholderIconSize: 80,
                placeholderBackgroundColor: AppColors.primaryColor,
              ),
              // Enhanced gradient overlay for better text readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.5, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: AppDim.paddingLarge,
                right: AppDim.paddingLarge,
                bottom: AppDim.paddingLarge,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      series.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDim.paddingSmall),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: Colors.amber.shade300,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          series.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shimmer-like placeholder for banner
  Widget _buildBannerShimmer() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDim.radiusLarge),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDim.radiusLarge),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppColors.primaryColor.withOpacity(0.08),
              AppColors.primaryColor.withOpacity(0.18),
              AppColors.primaryColor.withOpacity(0.08),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a series card for lists
  Widget _buildSeriesCard(Series series, BuildContext context, ThemeData theme) {
    return SizedBox(
      width: 140,
      height: 200, // Fixed height to prevent unbounded constraints
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        margin: const EdgeInsets.only(right: AppDim.paddingMedium),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MobilePageRoute(
                builder: (context) {
                  // Import and use the appropriate detail screen based on screen size
                  final screenWidth = MediaQuery.of(context).size.width;
                  if (screenWidth < 900) {
                    // Import at top of file will handle this
                    return MobileSeriesDetailScreen(series: series);
                  } else {
                    return SeriesDetailScreen(series: series);
                  }
                },
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Series Image (no heart icon)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: ImageWithPlaceholder(
                  imageUrl: series.imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  borderRadius: 0, // No border radius here since ClipRRect handles it
                  placeholderIcon: Icons.movie,
                  placeholderIconSize: 40,
                ),
              ),
              // Series Info - Fixed height section
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      series.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 13,
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
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shimmer-like horizontal list placeholder for series cards
  Widget _buildSeriesShimmerList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          width: 140,
          margin: const EdgeInsets.only(right: AppDim.paddingMedium),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image shimmer
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.08),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: 90,
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        Container(
                          height: 12,
                          width: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Message for empty sections
  Widget _buildEmptySectionMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
        child: Text(
          message,
          style: const TextStyle(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDim.radiusSmall),
        side: BorderSide(color: AppColors.primaryColor.withOpacity(0.3)),
      ),
    );
  }
}
