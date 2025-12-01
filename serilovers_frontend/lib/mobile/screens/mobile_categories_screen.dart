import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dim.dart';
import '../../models/series.dart';
import '../../providers/series_provider.dart';
import '../../providers/watchlist_provider.dart';
import '../../providers/auth_provider.dart';
import '../widgets/mobile_page_route.dart';
import 'mobile_series_detail_screen.dart';
import 'mobile_search_screen.dart';
import '../../core/widgets/image_with_placeholder.dart';

/// Mobile categories screen with horizontal filter tags and series display
class MobileCategoriesScreen extends StatefulWidget {
  const MobileCategoriesScreen({super.key});

  @override
  State<MobileCategoriesScreen> createState() => _MobileCategoriesScreenState();
}

class _MobileCategoriesScreenState extends State<MobileCategoriesScreen> {
  bool _initialized = false;
  int? _selectedGenreId; // null means "ALL"
  List<Series> _displayedSeries = [];
  bool _isLoadingSeries = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGenres();
      _loadAllSeries();
    });
  }

  Future<void> _loadGenres() async {
    if (_initialized) return;
    _initialized = true;
    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    await seriesProvider.fetchGenres();
  }

  Future<void> _loadAllSeries() async {
    setState(() {
      _isLoadingSeries = true;
    });
    
    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    try {
      await seriesProvider.fetchSeries(page: 1, pageSize: 100);
      _filterSeries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading series: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSeries = false;
        });
      }
    }
  }

  Future<void> _loadSeriesByGenre(int genreId) async {
    setState(() {
      _isLoadingSeries = true;
    });
    
    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    try {
      // Use fetchSeries with genreId filter instead
      await seriesProvider.fetchSeries(page: 1, pageSize: 100, genreId: genreId);
      setState(() {
        _displayedSeries = seriesProvider.items;
        _isLoadingSeries = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading series: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
        setState(() {
          _isLoadingSeries = false;
        });
      }
    }
  }

  void _filterSeries() {
    final seriesProvider = Provider.of<SeriesProvider>(context, listen: false);
    if (_selectedGenreId == null) {
      // Show all series
      setState(() {
        _displayedSeries = seriesProvider.items;
      });
    } else {
      // Filter by genre
      setState(() {
        _displayedSeries = seriesProvider.items.where((series) {
          return series.genres.any((genreName) {
            // Find genre by ID
            final genre = seriesProvider.genres.firstWhere(
              (g) => g.id == _selectedGenreId,
              orElse: () => Genre(id: -1, name: ''),
            );
            return genre.id != -1 && genreName.toLowerCase() == genre.name.toLowerCase();
          });
        }).toList();
      });
    }
  }

  void _onGenreSelected(int? genreId) async {
    setState(() {
      _selectedGenreId = genreId;
      _isLoadingSeries = true;
    });
    
    if (genreId == null) {
      // Show all series
      await _loadAllSeries();
    } else {
      // Load and show only series from selected genre
      await _loadSeriesByGenre(genreId);
    }
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
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // Navigate to profile - handled by bottom nav
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<SeriesProvider>(
          builder: (context, seriesProvider, child) {
            final genres = seriesProvider.genres;
            
            return Column(
              children: [
                // Horizontal scrollable filter tags - Show ALL genres
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppDim.paddingMedium),
                    itemCount: genres.length + 1, // +1 for "ALL"
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // "ALL" option
                        final isSelected = _selectedGenreId == null;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('ALL'),
                            selected: isSelected,
                            onSelected: (selected) {
                              _onGenreSelected(null);
                            },
                            selectedColor: AppColors.primaryColor,
                            checkmarkColor: AppColors.textLight,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.textLight : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        );
                      }
                      
                      final genre = genres[index - 1];
                      final isSelected = _selectedGenreId == genre.id;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(genre.name.toUpperCase()),
                          selected: isSelected,
                          onSelected: (selected) {
                            _onGenreSelected(selected ? genre.id : null);
                          },
                          selectedColor: AppColors.primaryColor,
                          checkmarkColor: AppColors.textLight,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.textLight : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      );
                    },
                  ),
                ),
                
                // Series list
                Expanded(
                  child: _isLoadingSeries
                      ? const Center(child: CircularProgressIndicator())
                      : _displayedSeries.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.movie_outlined,
                                    size: 64,
                                    color: AppColors.textSecondary.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: AppDim.paddingMedium),
                                  Text(
                                    'No series found',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppDim.paddingMedium,
                                horizontal: AppDim.paddingMedium,
                              ),
                              itemCount: _displayedSeries.length,
                              itemBuilder: (context, index) {
                                final series = _displayedSeries[index];
                                return _buildSeriesCard(series, context, theme);
                              },
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSeriesCard(Series series, BuildContext context, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDim.paddingMedium),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MobilePageRoute(
              builder: (context) => MobileSeriesDetailScreen(series: series),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Series Image - Use ImageWithPlaceholder for better handling
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ImageWithPlaceholder(
                  imageUrl: series.imageUrl,
                  width: 80,
                  height: 120,
                  fit: BoxFit.cover,
                  borderRadius: 8,
                  placeholderIcon: Icons.movie,
                  placeholderIconSize: 40,
                ),
              ),
              const SizedBox(width: 12),
              // Series Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series.title,
                      style: theme.textTheme.titleMedium?.copyWith(
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
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Add to list button
                    Consumer<WatchlistProvider>(
                      builder: (context, watchlistProvider, child) {
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showAddToListDialog(context, series),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add to list'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: AppColors.textLight,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        );
                      },
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
  final int seriesId;

  const _WatchlistSelector({required this.seriesId});

  @override
  State<_WatchlistSelector> createState() => _WatchlistSelectorState();
}

class _WatchlistSelectorState extends State<_WatchlistSelector> {
  int? _processingListId;

  @override
  Widget build(BuildContext context) {
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
                                    await Provider.of<WatchlistProvider>(
                                      context,
                                      listen: false,
                                    ).addSeries(list.id, widget.seriesId);

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
