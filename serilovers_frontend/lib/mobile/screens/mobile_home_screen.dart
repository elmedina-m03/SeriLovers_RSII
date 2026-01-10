import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../models/series.dart';
import '../../providers/series_provider.dart';
import '../../providers/watchlist_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../models/series_recommendation.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  DateTime? _lastLoadTime;
  static const _cacheTimeout = Duration(seconds: 10); // Cache for 10 seconds

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      // Update UI state but don't trigger search
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSeries();
      _loadRecommendations();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when returning to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _initialized) {
        final now = DateTime.now();
        if (_lastLoadTime == null || 
            now.difference(_lastLoadTime!) > _cacheTimeout) {
          _loadSeries(forceRefresh: true);
          _loadRecommendations();
        }
      }
    });
  }

  Future<void> _loadRecommendations() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final recommendationProvider = Provider.of<RecommendationProvider>(context, listen: false);
    
    if (authProvider.isAuthenticated) {
      try {
        await recommendationProvider.fetchRecommendations(maxResults: 10);
      } catch (e) {
        // Silently fail - recommendations are optional
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      _loadSeries();
      return;
    }

    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    try {
      await seriesProvider.searchSeries(query);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching series: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _loadSeries({bool forceRefresh = false}) async {
    if (!forceRefresh && _initialized) return;
    if (!_initialized) {
      _initialized = true;
    }

    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    try {
      // Load initial batch for pagination
      await seriesProvider.fetchSeries(page: 1, pageSize: 20);
      if (mounted) {
        setState(() {
          _lastLoadTime = DateTime.now();
        });
      }
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
        automaticallyImplyLeading: false, // No back button on home screen
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppDim.paddingMedium, 0, AppDim.paddingMedium, AppDim.paddingSmall),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search series by name...',
                hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
                prefixIcon: Icon(Icons.search, color: AppColors.primaryColor),
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.search, color: AppColors.primaryColor),
                        onPressed: () {
                          final query = _searchController.text.trim();
                          setState(() {
                            _searchQuery = query;
                          });
                          if (query.isEmpty) {
                            _loadSeries();
                          } else {
                            _performSearch(query);
                          }
                        },
                        tooltip: 'Search',
                      ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear, color: AppColors.textSecondary),
                        tooltip: 'Reset search and filters',
                        onPressed: () {
                          _searchController.clear();
                          final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
                          // Clear search and reset all filters
                          seriesProvider.clearSearch().then((_) {
                            if (mounted) {
                              // Reset active filter and reload all series
                              setState(() {
                                _searchQuery = '';
                                _activeFilter = null; // Reset filter
                              });
                              // Force fresh fetch to show all series
                              _loadSeries(forceRefresh: true);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
              style: TextStyle(color: AppColors.textPrimary),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
                if (value.trim().isEmpty) {
                  _loadSeries();
                } else {
                  _performSearch(value.trim());
                }
              },
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Consumer<SeriesProvider>(
          builder: (context, seriesProvider, child) {
            final isLoading = seriesProvider.isLoading && seriesProvider.items.isEmpty;
            // If searching, use search results directly; otherwise apply filters
            final filteredItems = _searchQuery.isNotEmpty 
                ? seriesProvider.items 
                : _applyFilter(seriesProvider.items);

            final perfectForYou = _getPerfectForYou(filteredItems);
            final summerSeries = _getSummerSeries(filteredItems);
            final topRated = _getTopRated(filteredItems);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium, vertical: AppDim.paddingSmall),
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

                  const SizedBox(height: AppDim.paddingSmall),

                  // "Choose a Series" Section - Two horizontal scrollable rows
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDim.paddingMedium,
                      AppDim.paddingSmall,
                      AppDim.paddingMedium,
                      AppDim.paddingSmall,
                    ),
                    child: Text(
                      'Choose a Series',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),

                  isLoading && filteredItems.isEmpty
                      ? SizedBox(height: 400, child: _buildSeriesShimmerList())
                      : filteredItems.isEmpty
                          ? SizedBox(height: 400, child: _buildEmptySectionMessage('No series available'))
                          : _buildTwoRowSeriesList(filteredItems, theme),

                  const SizedBox(height: AppDim.paddingLarge),

                  // "Favorites for You (Recommended)" Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDim.paddingMedium,
                      AppDim.paddingSmall,
                      AppDim.paddingMedium,
                      AppDim.paddingSmall,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Favorites for You',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(width: AppDim.paddingSmall),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDim.paddingSmall,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppDim.radiusSmall),
                          ),
                          child: Text(
                            'Recommended',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Consumer<RecommendationProvider>(
                    builder: (context, recommendationProvider, child) {
                      return Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          if (!authProvider.isAuthenticated) {
                            return SizedBox(
                              height: 200,
                              child: Center(
                                child: Text(
                                  'Sign in to see personalized recommendations',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }

                          if (recommendationProvider.isLoading) {
                            return SizedBox(height: 200, child: _buildSeriesShimmerList());
                          }

                          // If error or empty, show fallback with popular series
                          final recommendations = recommendationProvider.recommendations.take(10).toList();
                          final hasRecommendations = recommendations.isNotEmpty && recommendationProvider.error == null;

                          if (!hasRecommendations) {
                            // Fallback: show popular series (top rated)
                            final popularSeries = filteredItems
                                .where((s) => s.rating >= 7.0)
                                .take(3)
                                .toList();
                            
                            if (popularSeries.isEmpty) {
                              // If no popular series, just show first 3
                              final fallbackSeries = filteredItems.take(3).toList();
                              return SizedBox(
                                height: 200,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
                                  itemCount: fallbackSeries.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right: index < fallbackSeries.length - 1 ? AppDim.paddingMedium : 0,
                                      ),
                                      child: _buildSeriesCard(fallbackSeries[index], context, theme),
                                    );
                                  },
                                ),
                              );
                            }
                            
                            return SizedBox(
                              height: 200,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
                                itemCount: popularSeries.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right: index < popularSeries.length - 1 ? AppDim.paddingMedium : 0,
                                    ),
                                    child: _buildSeriesCard(popularSeries[index], context, theme),
                                  );
                                },
                              ),
                            );
                          }

                          return SizedBox(
                            height: 200,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
                              itemCount: recommendations.length,
                              itemBuilder: (context, index) {
                                final recommendation = recommendations[index];
                                return Padding(
                                  padding: EdgeInsets.only(
                                    right: index < recommendations.length - 1 ? AppDim.paddingMedium : 0,
                                  ),
                                  child: _buildRecommendationCard(recommendation, context, theme),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: AppDim.paddingLarge),
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

  /// Build two-row horizontal scrollable list (NOT GridView)
  Widget _buildTwoRowSeriesList(List<Series> series, ThemeData theme) {
    // Split series evenly between two rows
    final midPoint = (series.length / 2).ceil();
    final firstRow = series.sublist(0, midPoint);
    final secondRow = series.sublist(midPoint);

    return Column(
      children: [
        // First row - horizontal scrolling
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
            itemCount: firstRow.length,
            itemBuilder: (context, index) {
              final seriesItem = firstRow[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < firstRow.length - 1 ? AppDim.paddingMedium : 0,
                ),
                child: FadeSlideTransition(
                  delay: index * 50,
                  direction: SlideDirection.right,
                  child: _buildSeriesCard(seriesItem, context, theme),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppDim.paddingMedium),
        // Second row - horizontal scrolling
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
            itemCount: secondRow.length,
            itemBuilder: (context, index) {
              final seriesItem = secondRow[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < secondRow.length - 1 ? AppDim.paddingMedium : 0,
                ),
                child: FadeSlideTransition(
                  delay: index * 50,
                  direction: SlideDirection.right,
                  child: _buildSeriesCard(seriesItem, context, theme),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Build recommendation card
  Widget _buildRecommendationCard(SeriesRecommendation recommendation, BuildContext context, ThemeData theme) {
    return SizedBox(
      width: 140,
      height: 200,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        margin: const EdgeInsets.only(right: AppDim.paddingMedium),
        child: InkWell(
          onTap: () async {
            // Fetch full series details by ID
            final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
            try {
              // Try to get from cache first
              var series = seriesProvider.getById(recommendation.id);
              
              // If not in cache, fetch it
              if (series == null) {
                series = await seriesProvider.fetchSeriesDetail(recommendation.id);
              }
              
              if (series != null && mounted) {
                Navigator.push(
                  context,
                  MobilePageRoute(
                    builder: (context) => MobileSeriesDetailScreen(series: series!),
                  ),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Series not found'),
                    backgroundColor: AppColors.dangerColor,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error loading series: $e'),
                    backgroundColor: AppColors.dangerColor,
                  ),
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Series Image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: ImageWithPlaceholder(
                  imageUrl: recommendation.imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholderIcon: Icons.movie,
                  placeholderIconSize: 40,
                ),
              ),
              // Series Info
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recommendation.title,
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
                          recommendation.averageRating.toStringAsFixed(1),
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

}
